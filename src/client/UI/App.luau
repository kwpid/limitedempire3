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
local SettingsPage = require(script.Parent.Pages.SettingsPage)
local CosmeticsPage = require(script.Parent.Pages.CosmeticsPage)
local DataEditorPage = require(script.Parent.Pages.DataEditorPage)
local GamesPage = require(script.Parent.Pages.GamesPage)
local SeasonPage = require(script.Parent.Pages.SeasonPage)
local TradesPage = require(script.Parent.Pages.Trades.TradesPage)
local TradeComposer = require(script.Parent.Pages.Trades.TradeComposer)
local TabBar = require(script.Parent.Components.TabBar)
local OpeningOverlay = require(script.Parent.Opening.OpeningOverlay)
local RareReveal = require(script.Parent.Opening.RareReveal)
local InspectView = require(script.Parent.Inspect.InspectView)
local usePlayerState = require(script.Parent.Hooks.usePlayerState)
local useIsAdmin = require(script.Parent.Hooks.useIsAdmin)
local useFocusMode = require(script.Parent.Hooks.useFocusMode)
local useTrades = require(script.Parent.Hooks.useTrades)
local useTopbarIcon = require(script.Parent.Hooks.useTopbarIcon)
local Actions = require(script.Parent.Parent.Controllers.Actions)
local ClientSettings = require(script.Parent.Parent.Controllers.ClientSettings)
local Notifications = require(script.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Perf = require(script.Parent.Parent.Controllers.Perf)

local e = React.createElement

local INVENTORY_TABS = {
	{ id = "items", text = "Items" },
	{ id = "titles", text = "Titles" },
	{ id = "nameStyles", text = "Name Styles" },
}
local ADMIN_TABS = {
	{ id = "tools", text = "Tools" },
	{ id = "data", text = "Player Data" },
}
local TAB_HEIGHT = 32
-- settings sits in the Roblox topbar (TopbarPlus), next to Roblox's own buttons
local SETTINGS_ICON = { image = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png", caption = "Settings" }

local function playReveal(item)
	local traits = Traits.of(item)
	local trait = Traits.get(traits[1])
	local rank = ItemRegistry.tier(item.assetId).rank
	if rank >= 8 then
		Sfx.play("revealMythic", 0.65)
		Sfx.play("revealMythicSweep")
		Sfx.play("revealRare", 1.2)
	elseif (trait and trait.announce) or #traits > 1 or rank >= 6 or Valuation.value(item) >= Config.AnnounceValue then
		Sfx.play("revealMythic")
		Sfx.play("revealMythicSweep")
	elseif rank >= 4 or trait then
		Sfx.play("revealRare")
	else
		Sfx.play("reveal")
	end
end

-- Exotic and Divine unboxes get the RareReveal cutscene (it plays its own sounds) before the item is shown
local function hasCutscene(item): boolean
	local tier = ItemRegistry.tier(item.assetId)
	return tier.id == "exotic" or tier.id == "divine"
end

local function sellConfirm(value: number)
	return {
		text = "Confirm sell",
		holdSeconds = if value >= Config.SellHoldValue then Config.SellHoldSeconds else 0,
	}
end

local function gameName(id: string?): string?
	for _, entry in GamesPage.list do
		if entry.id == id then
			return entry.name
		end
	end
	return nil
end

local function caseSeriesName(case): string?
	for _, group in CaseRegistry.caseSeries() do
		if group.id == case.caseSeries then
			return group.name
		end
	end
	return nil
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
	local inventoryTab, setInventoryTab = React.useState("items")
	local adminTab, setAdminTab = React.useState("tools")
	local selectedGame, setSelectedGame = React.useState(nil)
	local autoOpen, setAutoOpen = React.useState(false)
	local autoRunning, setAutoRunning = React.useState(false)
	local autoCount, setAutoCount = React.useState(0)
	local trades = useTrades()
	-- the open trade composer: nil, or { counter? } (a new trade or a counter to one)
	local composing, setComposing = React.useState(nil)
	-- an item from a trade being inspected (it may not be yours)
	local inspectTradeItem, setInspectTradeItem = React.useState(nil)

	local inspectItem = inspectUid and state.inventory[inspectUid]
	local focused = opening ~= nil or inspectItem ~= nil or inspectTradeItem ~= nil
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

	-- auto-open: once the unboxed item has been shown for the autoOpenDelay setting, buy and open the same case again.
	-- the ref keeps the delayed call on the latest render so it sees fresh cash and busy state.
	local openCaseRef = React.useRef(openCase)
	openCaseRef.current = openCase
	local autoWaitingOn = if autoRunning and opening and opening.revealed and not opening.cutscene
		then opening.key
		else nil
	React.useEffect(function()
		if not autoWaitingOn then
			return nil
		end
		local caseId = opening.caseId
		local thread = task.delay(ClientSettings.get("autoOpenDelay") or 1.5, function()
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

	useTopbarIcon(SETTINGS_ICON, page == "settings", function(selected: boolean)
		if selected then
			Sfx.play("tab")
			navigate("settings")
		else
			setPage(function(current)
				return if current == "settings" then nil else current
			end)
		end
	end, not focused)

	local focusContent
	if opening and not opening.revealed then
		focusContent = e(OpeningOverlay, {
			caseId = opening.caseId,
			item = opening.item,
			onRevealed = function()
				Perf.note("reveal")
				Perf.measureNextFrame("reveal first frame")
				local cutscene = hasCutscene(opening.item)
				if not cutscene then
					playReveal(opening.item)
				end
				setOpening(function(current)
					if current and current.key == opening.key then
						local nextOpening = table.clone(current)
						nextOpening.revealed = true
						nextOpening.cutscene = cutscene
						return nextOpening
					end
					return current
				end)
			end,
		})
	elseif opening and opening.cutscene and opening.item then
		focusContent = e(RareReveal, {
			item = opening.item,
			onDone = function()
				setOpening(function(current)
					if current and current.key == opening.key then
						local nextOpening = table.clone(current)
						nextOpening.cutscene = false
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
		local autoSoldFor = opening.item.autoSoldFor
		local again = {
			text = case and `Again {Format.cash(case.price)}` or "Again",
			width = 190,
			color = Theme.colors.good,
			disabled = busy or autoRunning or not case or state.cash < case.price,
			onClick = function()
				startCase(opening.caseId)
			end,
		}
		local caption = if CaseRegistry.isSpecial(opening.item.assetId)
			then "★ You unboxed a rare special item"
			else "You unboxed"
		if autoSoldFor then
			caption = `Auto-sold for {Format.cash(autoSoldFor)}`
		end
		focusContent = e(InspectView, {
			item = opening.item,
			caption = caption,
			captionColor = if autoSoldFor
				then Theme.colors.cash
				elseif CaseRegistry.isSpecial(opening.item.assetId) then Theme.colors.special
				else nil,
			actions = if autoSoldFor
				then {
					{
						text = "Continue",
						width = 150,
						onClick = function()
							stopAuto()
							setOpening(nil)
						end,
					},
					again,
				}
				else {
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
					again,
				},
		})
	elseif inspectTradeItem then
		focusContent = e(InspectView, {
			item = inspectTradeItem,
			caption = if state.inventory[inspectTradeItem.uid] then "Your item" else "Trade item",
			onClose = function()
				setInspectTradeItem(nil)
			end,
			actions = {},
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
	local availableCases = 0
	for _, case in CaseRegistry.list() do
		if CaseRegistry.isAvailable(case) then
			availableCases += 1
		end
	end
	local inventoryCount = 0
	for _ in state.inventory do
		inventoryCount += 1
	end
	local inboundTrades = 0
	for _, trade in trades do
		if trade.direction == "inbound" and trade.status == "pending" then
			inboundTrades += 1
		end
	end

	local main = {
		Wallet = e(Wallet),
		BottomNav = e(BottomNav, {
			page = page,
			onNavigate = navigate,
			badges = { trades = inboundTrades },
		}),
		CasesWindow = e(Window, {
			visible = page == "cases",
			title = selectedCase and selectedCase.name or "Cases",
			subtitle = if selectedCase
				then caseSeriesName(selectedCase)
				else `{#CaseRegistry.caseSeries()} series  ·  {availableCases} cases`,
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
			Tabs = e(TabBar, {
				size = UDim2.new(1, 0, 0, TAB_HEIGHT),
				tabs = INVENTORY_TABS,
				value = inventoryTab,
				onChange = setInventoryTab,
			}),
			Content = e("Frame", {
				Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
				Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
				BackgroundTransparency = 1,
			}, {
				Items = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = inventoryTab == "items",
				}, {
					Page = e(InventoryPage, {
						inventory = state.inventory,
						equipped = state.equipped,
						pinned = state.pinned,
						onInspect = setInspectUid,
					}),
				}),
				Titles = inventoryTab == "titles" and e(CosmeticsPage, { kind = "title" }),
				NameStyles = inventoryTab == "nameStyles" and e(CosmeticsPage, { kind = "nameStyle" }),
			}),
		}),
		GamesWindow = e(Window, {
			visible = page == "games",
			title = gameName(selectedGame) or "Games",
			subtitle = if selectedGame then nil else `{#GamesPage.list} games`,
			onBack = if selectedGame
				then function()
					setSelectedGame(nil)
				end
				else nil,
			onClose = close,
		}, {
			Page = page == "games" and e(GamesPage.component, {
				game = selectedGame,
				onSelect = setSelectedGame,
				cash = state.cash,
				inventory = state.inventory,
				equipped = state.equipped,
				pinned = state.pinned,
				onInspect = setInspectUid,
			}),
		}),
		TradesWindow = e(Window, {
			visible = page == "trades",
			title = if composing and composing.counter
				then "Counter trade"
				elseif composing then "New trade"
				else "Trades",
			subtitle = if composing
				then `up to {Config.Trade.MaxItems} items a side`
				elseif inboundTrades > 0 then `{inboundTrades} waiting on you`
				else nil,
			onBack = if composing
				then function()
					setComposing(nil)
				end
				else nil,
			onClose = close,
		}, {
			List = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = composing == nil,
			}, {
				Page = e(TradesPage, {
					trades = trades,
					inventory = state.inventory,
					onCompose = setComposing,
					onInspectItem = setInspectTradeItem,
				}),
			}),
			Composer = page == "trades" and composing and e(TradeComposer, {
				inventory = state.inventory,
				counter = composing.counter,
				onInspectItem = setInspectTradeItem,
				onDone = function()
					setComposing(nil)
				end,
			}) or nil,
		}),
		SeasonWindow = e(Window, {
			visible = page == "season",
			title = "Season",
			subtitle = "ranks, career and quests",
			onClose = close,
		}, {
			Page = page == "season" and e(SeasonPage, {
				progress = state.progress,
				visible = page == "season",
			}),
		}),
		SettingsWindow = e(Window, {
			visible = page == "settings",
			title = "Settings",
			subtitle = "saved to your account",
			onClose = close,
		}, {
			Page = e(SettingsPage, { stats = state.stats }),
		}),
		AdminWindow = if isAdmin
			then e(Window, {
				visible = page == "admin",
				title = "Admin",
				subtitle = "developer tools",
				onClose = close,
			}, {
				Tabs = e(TabBar, {
					size = UDim2.new(1, 0, 0, TAB_HEIGHT),
					tabs = ADMIN_TABS,
					value = adminTab,
					onChange = setAdminTab,
				}),
				Content = e("Frame", {
					Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
					Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
					BackgroundTransparency = 1,
				}, {
					Tools = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = adminTab == "tools",
					}, {
						Page = e(AdminPage, { cash = state.cash }),
					}),
					Data = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = adminTab == "data",
					}, {
						Page = e(DataEditorPage),
					}),
				}),
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
			then `Opening{opening.key}{if opening.cutscene then "Cutscene" elseif opening.revealed then "Reveal" else "Reel"}`
			elseif inspectTradeItem then `InspectTrade{inspectTradeItem.uid}`
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
