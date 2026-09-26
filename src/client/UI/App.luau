local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Theme)
local Wallet = require(script.Parent.Components.Wallet)
local BottomNav = require(script.Parent.Components.BottomNav)
local Toasts = require(script.Parent.Components.Toasts)
local Window = require(script.Parent.Components.Window)
local Button = require(script.Parent.Components.Button)
local CasesPage = require(script.Parent.Pages.CasesPage)
local CaseDetails = require(script.Parent.Pages.CaseDetails)
local InventoryPage = require(script.Parent.Pages.InventoryPage)
local AdminPage = require(script.Parent.Pages.AdminPage)
local OpeningOverlay = require(script.Parent.Opening.OpeningOverlay)
local InspectView = require(script.Parent.Inspect.InspectView)
local usePlayerState = require(script.Parent.Hooks.usePlayerState)
local useIsAdmin = require(script.Parent.Hooks.useIsAdmin)
local useFocusMode = require(script.Parent.Hooks.useFocusMode)
local Actions = require(script.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Perf = require(script.Parent.Parent.Controllers.Perf)

local e = React.createElement

local AUTO_OPEN_DELAY = 1.5

local function playReveal(item)
	local trait = Traits.get(item.trait)
	local rank = ItemRegistry.tier(item.assetId).rank
	if rank >= 8 then
		Sfx.play("revealMythic", 0.65)
		Sfx.play("revealMythicSweep")
		Sfx.play("revealRare", 1.2)
	elseif (trait and trait.announce) or rank >= 6 or Valuation.value(item) >= Config.AnnounceValue then
		Sfx.play("revealMythic")
		Sfx.play("revealMythicSweep")
	elseif rank >= 4 or trait then
		Sfx.play("revealRare")
	else
		Sfx.play("reveal")
	end
end

local function sellConfirm(value: number)
	return {
		text = "Confirm sell",
		holdSeconds = if value >= Config.SellHoldValue then Config.SellHoldSeconds else 0,
	}
end

local function fail(message: string?)
	Sfx.play("error")
	Notifications.push(message or "Something went wrong", Theme.colors.bad)
end

local function App(props)
	local state = usePlayerState()
	local isAdmin = useIsAdmin()
	local page, setPage = React.useState("cases")
	local selectedCaseId, setSelectedCaseId = React.useState(nil)
	local opening, setOpening = React.useState(nil)
	local inspectUid, setInspectUid = React.useState(nil)
	local busy, setBusy = React.useState(false)
	local autoOpen, setAutoOpen = React.useState(false)
	local autoRunning, setAutoRunning = React.useState(false)
	local autoCount, setAutoCount = React.useState(0)

	local inspectItem = inspectUid and state.inventory[inspectUid]
	local focused = opening ~= nil or inspectItem ~= nil
	useFocusMode(focused)

	React.useLayoutEffect(function()
		if inspectUid and not inspectItem then
			setInspectUid(nil)
		end
	end, { inspectUid, inspectItem })

	local function stopAuto()
		setAutoRunning(false)
	end

	local function openCase(caseId: string, auto: boolean?)
		local case = CaseRegistry.get(caseId)
		if busy or not case then
			return
		end
		if state.cash < case.price then
			if auto then
				stopAuto()
				fail(`Auto-open stopped, not enough {Config.Currency.Name}`)
			else
				fail(`Not enough {Config.Currency.Name}`)
			end
			return
		end
		if auto then
			setAutoCount(function(count)
				return count + 1
			end)
		end
		local key = os.clock()
		Perf.note("open clicked")
		Perf.measureNextFrame("reel first frame")
		setBusy(true)
		setOpening({ caseId = caseId, item = nil, key = key, revealed = false })
		task.spawn(function()
			local result = Actions.openCase(caseId)
			Perf.report("server open round trip", os.clock() - key)
			setBusy(false)
			setOpening(function(current)
				if not current or current.key ~= key then
					return current
				end
				if not result.ok then
					return nil
				end
				local nextOpening = table.clone(current)
				nextOpening.item = result.data
				return nextOpening
			end)
			if not result.ok then
				stopAuto()
				fail(result.err)
			end
		end)
	end

	local function startCase(caseId: string)
		if autoOpen then
			setAutoCount(0)
			setAutoRunning(true)
			openCase(caseId, true)
		else
			openCase(caseId)
		end
	end

	-- auto-open: once the unboxed item has been shown for AUTO_OPEN_DELAY, buy and open the same case again.
	-- the ref keeps the delayed call on the latest render so it sees fresh cash and busy state.
	local openCaseRef = React.useRef(openCase)
	openCaseRef.current = openCase
	local autoWaitingOn = if autoRunning and opening and opening.revealed then opening.key else nil
	React.useEffect(function()
		if not autoWaitingOn then
			return nil
		end
		local caseId = opening.caseId
		local thread = task.delay(AUTO_OPEN_DELAY, function()
			openCaseRef.current(caseId, true)
		end)
		return function()
			pcall(task.cancel, thread)
		end
	end, { autoWaitingOn })

	local function sell(uid: string, onDone: () -> ())
		setBusy(true)
		task.spawn(function()
			local result = Actions.sell({ uid })
			setBusy(false)
			if result.ok then
				Sfx.play("sell")
				Notifications.push(`Sold for {Format.cash(result.data)}`, Theme.colors.cash)
				onDone()
			else
				fail(result.err)
			end
		end)
	end

	local function toggleEquip(uid: string)
		setBusy(true)
		task.spawn(function()
			local result = Actions.toggleEquipped(uid)
			setBusy(false)
			if not result.ok then
				fail(result.err)
			end
		end)
	end

	local close = React.useCallback(function()
		setPage(nil)
	end, {})

	local backToCases = React.useCallback(function()
		setSelectedCaseId(nil)
	end, {})

	local navigate = React.useCallback(function(nextPage)
		Perf.measureNextFrame(`open tab {nextPage or "none"}`)
		setPage(nextPage)
		if nextPage ~= "cases" then
			setSelectedCaseId(nil)
		end
	end, {})

	local focusContent
	if opening and not opening.revealed then
		focusContent = e(OpeningOverlay, {
			caseId = opening.caseId,
			item = opening.item,
			onRevealed = function()
				Perf.note("reveal")
				Perf.measureNextFrame("reveal first frame")
				playReveal(opening.item)
				setOpening(function(current)
					if current and current.key == opening.key then
						local nextOpening = table.clone(current)
						nextOpening.revealed = true
						return nextOpening
					end
					return current
				end)
			end,
		})
	elseif opening and opening.item then
		local case = CaseRegistry.get(opening.caseId)
		local owned = state.inventory[opening.item.uid] ~= nil
		local sellValue = math.floor(Valuation.value(opening.item) * Config.SellRate)
		focusContent = e(InspectView, {
			item = opening.item,
			caption = if CaseRegistry.isSpecial(opening.item.assetId) then "★ You unboxed a rare special item" else "You unboxed",
			captionColor = if CaseRegistry.isSpecial(opening.item.assetId) then Theme.colors.special else nil,
			actions = {
				{
					text = `Sell {Format.cash(sellValue)}`,
					confirm = sellConfirm(sellValue),
					width = 170,
					disabled = busy or not owned,
					sound = false,
					onClick = function()
						stopAuto()
						sell(opening.item.uid, function()
							setOpening(nil)
						end)
					end,
				},
				{
					text = "Keep",
					width = 120,
					onClick = function()
						stopAuto()
						setOpening(nil)
					end,
				},
				{
					text = case and `Again {Format.cash(case.price)}` or "Again",
					width = 190,
					color = Theme.colors.good,
					disabled = busy or autoRunning or not case or state.cash < case.price,
					onClick = function()
						startCase(opening.caseId)
					end,
				},
			},
		})
	elseif inspectItem then
		local equipped = table.find(state.equipped, inspectItem.uid) ~= nil
		local equippable = ItemRegistry.isEquippable(inspectItem.assetId)
		local sellValue = math.floor(Valuation.value(inspectItem) * Config.SellRate)
		focusContent = e(InspectView, {
			item = inspectItem,
			caption = "Inspect",
			onClose = function()
				setInspectUid(nil)
			end,
			actions = {
				{
					text = if not equippable then "Can't wear" elseif equipped then "Unequip" else "Equip",
					width = 140,
					disabled = busy or not equippable,
					sound = "equip",
					onClick = function()
						toggleEquip(inspectItem.uid)
					end,
				},
				{
					text = `Sell {Format.cash(sellValue)}`,
					confirm = sellConfirm(sellValue),
					width = 170,
					disabled = busy,
					sound = false,
					onClick = function()
						sell(inspectItem.uid, function()
							setInspectUid(nil)
						end)
					end,
				},
			},
		})
	end

	local selectedCase = selectedCaseId and CaseRegistry.get(selectedCaseId)
	local inventoryCount = 0
	for _ in state.inventory do
		inventoryCount += 1
	end

	local main = {
		Wallet = e(Wallet),
		BottomNav = e(BottomNav, {
			page = page,
			onNavigate = navigate,
		}),
		CasesWindow = e(Window, {
			visible = page == "cases",
			title = selectedCase and selectedCase.name or "Cases",
			subtitle = if selectedCase then nil else `{#CaseRegistry.list()} cases available`,
			onBack = if selectedCase then backToCases else nil,
			onClose = close,
		}, {
			List = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = selectedCase == nil,
			}, {
				Page = e(CasesPage, {
					cash = state.cash,
					onSelect = setSelectedCaseId,
				}),
			}),
			Details = selectedCase and e(CaseDetails, {
				caseId = selectedCase.id,
				cash = state.cash,
				busy = busy,
				autoOpen = autoOpen,
				onToggleAuto = function()
					setAutoOpen(not autoOpen)
				end,
				onOpen = startCase,
			}),
		}),
		InventoryWindow = e(Window, {
			visible = page == "inventory",
			title = "Inventory",
			subtitle = `{inventoryCount} items`,
			onClose = close,
		}, {
			Page = e(InventoryPage, {
				inventory = state.inventory,
				equipped = state.equipped,
				onInspect = setInspectUid,
			}),
		}),
		AdminWindow = if isAdmin
			then e(Window, {
				visible = page == "admin",
				title = "Admin",
				subtitle = "developer tools",
				onClose = close,
			}, {
				Page = e(AdminPage, { cash = state.cash }),
			})
			else nil,
	}

	local children = {
		Main = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = focusContent == nil,
		}, main),
	}

	local focusChildren = {
		Toasts = e(Toasts),
		StopAuto = if autoRunning
			then e(Button, {
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 16),
				size = UDim2.fromOffset(260, 40),
				text = `Stop auto-open  ·  {autoCount} opened`,
				textSize = 16,
				color = Theme.colors.bad,
				zIndex = 20,
				onClick = stopAuto,
			})
			else nil,
	}
	if focusContent then
		local contentKey = if opening
			then `Opening{opening.key}{opening.revealed and "Reveal" or "Reel"}`
			else `Inspect{inspectUid}`
		focusChildren[contentKey] = focusContent
	end
	children.Focus = ReactRoblox.createPortal(focusChildren, props.focusGui)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return App
