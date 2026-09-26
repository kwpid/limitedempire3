-- Upgrader: pick up to Upgrader.MAX_INPUTS of your items (left) and a more valuable target (right). the chance
-- is shown in the middle over a bar whose green part is the winning zone; the server rolls, and a marker sweeps
-- back and forth before landing on the roll. props: inventory, equipped, pinned, onInspect(uid)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Upgrader = require(Shared.Games.Upgrader)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Parent.Components.ItemTile)
local SearchBox = require(script.Parent.Parent.Parent.Components.SearchBox)
local ItemPicker = require(script.Parent.ItemPicker)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local SIDE_WIDTH = 300
local SPIN_TIME = 2.4
local MAX_TARGETS = 90
-- target list starts at this many times the value put in (lots of items sit just above any value, so without this
-- the first page would always be targets at the max chance)
local MULTIPLIERS = { 1.5, 2, 3, 5, 10, 25 }

-- the marker bounces across the bar a few times and lands on the roll
local function markerAt(roll: number, p: number): number
	local travel = (1 - (1 - p) ^ 3) * (4 + roll)
	local phase = travel % 2
	return if phase <= 1 then phase else 2 - phase
end

local function UpgraderPage(props)
	local selected, setSelected = React.useState({})
	local target, setTarget = React.useState(nil)
	local targetQuery, setTargetQuery = React.useState("")
	local multiplier, setMultiplier = React.useState(2)
	local pending, setPending = React.useState(false)
	local spin, setSpin = React.useState(nil)
	local marker, setMarker = React.useBinding(0)

	-- drop selections that left the inventory (sold, used elsewhere)
	local selectedList = {}
	local inputValue = 0
	for uid in selected do
		local item = props.inventory[uid]
		if item then
			table.insert(selectedList, item)
			inputValue += Valuation.value(item)
		end
	end
	table.sort(selectedList, function(a, b)
		return Valuation.value(a) > Valuation.value(b)
	end)

	local targetValue = target and ItemRegistry.baseValue(target) or 0
	local chance = if target then Upgrader.chance(inputValue, targetValue) else 0

	React.useEffect(function()
		if not spin then
			return nil
		end
		local start = os.clock()
		local finished = false
		local lastSide = nil
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local p = math.clamp((os.clock() - start) / SPIN_TIME, 0, 1)
			local x = markerAt(spin.roll, p)
			setMarker(x)
			local side = x < spin.chance
			if side ~= lastSide then
				lastSide = side
				Sfx.play("tick", if side then 1.1 else 0.9)
			end
			if p >= 1 and not finished then
				finished = true
				connection:Disconnect()
				if spin.won then
					Sfx.play("revealRare")
					local info = spin.item and ItemRegistry.get(spin.item.assetId)
					Notifications.push(`Upgrade won: {info and info.name or "item"}!`, Theme.colors.good)
				else
					Sfx.play("error")
				end
				setSpin(function(current)
					if current and current.key == spin.key then
						local nextSpin = table.clone(current)
						nextSpin.done = true
						return nextSpin
					end
					return current
				end)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { spin and spin.key } :: { any })

	local spinning = spin ~= nil and not spin.done

	local function toggle(uid: string)
		if spinning then
			return
		end
		local nextSelected = table.clone(selected)
		if nextSelected[uid] then
			nextSelected[uid] = nil
		elseif #selectedList < Upgrader.MAX_INPUTS then
			nextSelected[uid] = true
		else
			Notifications.push(`You can put in up to {Upgrader.MAX_INPUTS} items`, Theme.colors.bad)
			return
		end
		setSelected(nextSelected)
		setSpin(nil)
	end

	local function upgrade()
		if pending or spinning or not target or chance <= 0 then
			return
		end
		local uids = {}
		for _, item in selectedList do
			table.insert(uids, item.uid)
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.upgrade(uids, target)
			setPending(false)
			if not result.ok then
				Sfx.play("error")
				Notifications.push(result.err or "Upgrade failed", Theme.colors.bad)
				return
			end
			setSelected({})
			setSpin({
				key = os.clock(),
				roll = result.data.roll,
				chance = result.data.chance,
				won = result.data.won,
				item = result.data.item,
				done = false,
			})
		end)
	end

	-- targets worth more than the input and at least a 1% chance, nearest first
	local targetTiles = {}
	local needle = string.lower(targetQuery)
	local count = 0
	local minValue = inputValue * multiplier
	for _, assetId in Upgrader.targets() do
		if count >= MAX_TARGETS then
			break
		end
		local value = ItemRegistry.baseValue(assetId)
		local c = Upgrader.chance(inputValue, value)
		if inputValue > 0 and (c <= 0 or (needle == "" and value < minValue)) then
			continue
		end
		local info = ItemRegistry.get(assetId)
		if needle ~= "" and not string.find(string.lower(info and info.name or ""), needle, 1, true) then
			continue
		end
		count += 1
		targetTiles[tostring(assetId)] = e(ItemTile, {
			id = assetId,
			layoutOrder = count,
			assetId = assetId,
			subtitle = Format.cash(value),
			selected = assetId == target,
			tagText = if inputValue > 0 then Format.percent(c) else nil,
			tagColor = Theme.colors.good,
			onSelect = function(id)
				if not spinning then
					setTarget(id)
					setSpin(nil)
				end
			end,
		})
	end

	local slots = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, Upgrader.MAX_INPUTS do
		local item = selectedList[index]
		slots["Slot" .. index] = e("ImageLabel", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			Image = if item then ItemRegistry.thumbnail(item.assetId, 150) else "",
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if item then ItemRegistry.tier(item.assetId).color else Theme.colors.stroke,
			}),
		})
	end

	local shownChance = if spin then spin.chance else chance
	local targetInfo = target and ItemRegistry.get(target)
	local resultText, resultColor = "", Theme.colors.textDim
	if spin and spin.done then
		if spin.won then
			resultText, resultColor = "UPGRADED!", Theme.colors.good
		else
			resultText, resultColor = "LOST", Theme.colors.bad
		end
	elseif spinning then
		resultText = "Rolling..."
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Inputs = e(ItemPicker, {
			size = UDim2.new(0, SIDE_WIDTH, 1, 0),
			inventory = props.inventory,
			equipped = props.equipped,
			pinned = props.pinned,
			selected = selected,
			onToggle = toggle,
			title = `Your items ({#selectedList}/{Upgrader.MAX_INPUTS})`,
		}),
		Middle = e("Frame", {
			Position = UDim2.fromOffset(SIDE_WIDTH + 12, 0),
			Size = UDim2.new(1, -(SIDE_WIDTH * 2 + 24), 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			Slots = e("Frame", {
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
			}, slots),
			Input = e(Text, {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 16),
				Text = `Putting in {Format.cash(inputValue)}`,
				TextSize = 13,
				TextColor3 = Theme.colors.cash,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			TargetThumb = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 84),
				Size = UDim2.fromOffset(96, 96),
				BackgroundTransparency = 1,
				Image = if target then ItemRegistry.thumbnail(target, 420) else "",
			}),
			TargetName = e(Text, {
				Position = UDim2.fromOffset(0, 184),
				Size = UDim2.new(1, 0, 0, 18),
				Text = if targetInfo
					then `{targetInfo.name}  ·  {Format.cash(targetValue)}`
					else "Pick a target on the right",
				TextSize = 13,
				TextColor3 = if target then ItemRegistry.tier(target).color else Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Chance = e(Text, {
				Position = UDim2.fromOffset(0, 210),
				Size = UDim2.new(1, 0, 0, 44),
				Text = if shownChance > 0 then Format.percent(shownChance) else "-",
				TextSize = 40,
				TextColor3 = if resultText ~= "" and spin and spin.done then resultColor else Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			ChanceLabel = e(Text, {
				Position = UDim2.fromOffset(0, 254),
				Size = UDim2.new(1, 0, 0, 14),
				Text = `chance to win  ·  {math.floor(Upgrader.HOUSE_EDGE * 100)}% house edge, {math.floor(
					Upgrader.MAX_CHANCE * 100
				)}% max`,
				TextSize = 11,
				TextColor3 = Theme.colors.textFaint,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Bar = e("Frame", {
				Position = UDim2.fromOffset(0, 282),
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Win = e("Frame", {
					Size = UDim2.fromScale(shownChance, 1),
					BackgroundColor3 = Theme.colors.good,
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = Theme.radius }),
				}),
				Marker = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = marker:map(function(x)
						return UDim2.fromScale(x, 0.5)
					end),
					Size = UDim2.new(0, 4, 1, 10),
					BackgroundColor3 = Theme.colors.marker,
					BorderSizePixel = 0,
					Visible = spin ~= nil,
					ZIndex = 2,
				}),
			}),
			Result = e(Text, {
				Position = UDim2.fromOffset(0, 312),
				Size = UDim2.new(1, 0, 0, 26),
				Text = resultText,
				TextSize = 22,
				TextColor3 = resultColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Upgrade = e(Button, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				size = UDim2.new(1, 0, 0, 42),
				text = if spin
						and spin.done
						and spin.won
						and spin.item
					then "Inspect your new item"
					elseif pending or spinning then "Upgrading..."
					else "Upgrade",
				textSize = 18,
				color = Theme.colors.good,
				disabled = pending
					or spinning
					or (not (spin and spin.done and spin.won) and (not target or chance <= 0)),
				onClick = function()
					if spin and spin.done and spin.won and spin.item then
						props.onInspect(spin.item.uid)
						setSpin(nil)
					else
						upgrade()
					end
				end,
			}),
		}),
		Targets = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, SIDE_WIDTH, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 18),
				Text = if inputValue > 0 then `Target  ·  {multiplier}x and up` else "Target",
				TextSize = 15,
				display = true,
			}),
			Search = e(SearchBox, {
				position = UDim2.fromOffset(0, 24),
				size = UDim2.new(1, 0, 0, 28),
				value = targetQuery,
				placeholder = "Search targets...",
				onChange = setTargetQuery,
			}),
			Multipliers = e("Frame", {
				Position = UDim2.fromOffset(0, 58),
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
			}, (function()
				local children = {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}
				for index, value in MULTIPLIERS do
					children["X" .. index] = e(Button, {
						layoutOrder = index,
						size = UDim2.new(1 / #MULTIPLIERS, -4, 1, 0),
						text = `{value}x`,
						textSize = 12,
						color = if multiplier == value then Theme.colors.accent else nil,
						sound = "tab",
						onClick = function()
							setMultiplier(value)
						end,
					})
				end
				return children
			end)()),
			Items = e(Grid, {
				position = UDim2.fromOffset(0, 88),
				size = UDim2.new(1, 0, 1, -88),
				cellSize = UDim2.fromOffset(92, 118),
				cellPadding = UDim2.fromOffset(5, 5),
			}, targetTiles),
		}),
	})
end

return UpgraderPage
