-- Trade-Up: pick a rarity, fill the contract with TradeUp.COUNT of your items of that rarity (left), and see the
-- result rarity, the result float (average of the inputs) and every possible result with its odds (right) before
-- trading up. props: inventory, equipped, pinned, onInspect(uid)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Tiers = require(Shared.Items.Tiers)
local TradeUp = require(Shared.Games.TradeUp)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Dropdown = require(script.Parent.Parent.Parent.Components.Dropdown)
local ItemPicker = require(script.Parent.ItemPicker)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local PICKER_WIDTH = 470
local MAX_OUTCOMES = 40

local RARITY_OPTIONS = {}
for _, tier in Tiers.list do
	if TradeUp.nextTier(tier.id) then
		table.insert(RARITY_OPTIONS, { id = tier.id, label = tier.name, color = tier.color })
	end
end

local function OutcomeRow(props)
	local info = ItemRegistry.get(props.assetId)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Thumb = e("ImageLabel", {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(props.assetId, 150),
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -170, 1, 0),
			Text = info and info.name or "Unknown",
			TextSize = 12,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -64, 0, 0),
			Size = UDim2.new(0, 70, 1, 0),
			Text = Format.cash(ItemRegistry.baseValue(props.assetId)),
			TextSize = 12,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Chance = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.new(0, 54, 1, 0),
			Text = Format.percent(props.chance),
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function TradeUpPage(props)
	local rarity, setRarity = React.useState(RARITY_OPTIONS[1].id)
	local selected, setSelected = React.useState({})
	local pending, setPending = React.useState(false)
	local result, setResult = React.useState(nil)

	local selectedList = {}
	for uid in selected do
		local item = props.inventory[uid]
		if item then
			table.insert(selectedList, item)
		end
	end
	table.sort(selectedList, function(a, b)
		return a.uid < b.uid
	end)

	local outcomes = TradeUp.outcomes(selectedList)

	local nextTier = TradeUp.nextTier(rarity)
	local full = #selectedList == TradeUp.COUNT

	local function toggle(uid: string)
		local nextSelected = table.clone(selected)
		if nextSelected[uid] then
			nextSelected[uid] = nil
		elseif #selectedList < TradeUp.COUNT then
			nextSelected[uid] = true
		else
			Notifications.push(`The contract is full ({TradeUp.COUNT} items)`, Theme.colors.bad)
			return
		end
		setSelected(nextSelected)
		setResult(nil)
	end

	local function tradeUp()
		if pending or not full then
			return
		end
		local uids = {}
		for _, item in selectedList do
			table.insert(uids, item.uid)
		end
		setPending(true)
		task.spawn(function()
			local response = Actions.tradeUp(uids)
			setPending(false)
			if not response.ok then
				Sfx.play("error")
				Notifications.push(response.err or "Trade-up failed", Theme.colors.bad)
				return
			end
			Sfx.play("revealRare")
			setSelected({})
			setResult(response.data)
		end)
	end

	local slots = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(48, 48),
			CellPadding = UDim2.fromOffset(5, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, TradeUp.COUNT do
		local item = selectedList[index]
		slots["Slot" .. index] = e("ImageButton", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Image = if item then ItemRegistry.thumbnail(item.assetId, 150) else "",
			[React.Event.Activated] = function()
				if item then
					toggle(item.uid)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if item then ItemRegistry.tier(item.assetId).color else Theme.colors.stroke,
			}),
		})
	end

	local outcomeRows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index = 1, math.min(MAX_OUTCOMES, #outcomes) do
		local outcome = outcomes[index]
		outcomeRows[tostring(outcome.assetId)] = e(OutcomeRow, {
			layoutOrder = index,
			assetId = outcome.assetId,
			chance = outcome.chance,
		})
	end

	local float = if #selectedList > 0 then TradeUp.float(selectedList) else nil
	local resultInfo = result and ItemRegistry.get(result.assetId)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Rarity = e(Dropdown, {
			position = UDim2.new(0, PICKER_WIDTH - 170, 0, 0),
			size = UDim2.fromOffset(170, 24),
			label = "Rarity",
			options = RARITY_OPTIONS,
			value = rarity,
			onChange = function(id)
				setRarity(id)
				setSelected({})
				setResult(nil)
			end,
		}),
		Picker = e(ItemPicker, {
			size = UDim2.new(0, PICKER_WIDTH, 1, 0),
			inventory = props.inventory,
			equipped = props.equipped,
			pinned = props.pinned,
			selected = selected,
			onToggle = toggle,
			sort = "value_asc",
			title = `Your {Tiers.get(rarity).name} items`,
			filter = function(item)
				return ItemRegistry.tier(item.assetId).id == rarity
			end,
			emptyText = `No usable {Tiers.get(rarity).name} items. Equipped, pinned and custom items can't be used.`,
		}),
		Contract = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -(PICKER_WIDTH + 12), 1, 0),
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
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Contract  {#selectedList}/{TradeUp.COUNT}`,
				TextSize = 15,
				display = true,
			}),
			Slots = e("Frame", {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.fromOffset(5 * 53, 2 * 53),
				BackgroundTransparency = 1,
			}, slots),
			Info = e(Text, {
				Position = UDim2.fromOffset(5 * 53 + 12, 26),
				Size = UDim2.new(1, -(5 * 53 + 12), 0, 100),
				Text = if nextTier
					then `Result rarity: {nextTier.name}\nResult float: {if float
						then `{Format.float(float)} ({Condition.fromFloat(float).name})`
						else "-"}\nResults are worth at most {TradeUp.MAX_RETURN}x what you put in.\nTraits and stat trackers are not kept.`
					else "",
				TextSize = 12,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			OutcomesTitle = e(Text, {
				Position = UDim2.fromOffset(0, 140),
				Size = UDim2.new(1, 0, 0, 16),
				Text = if #outcomes > 0
					then `Possible results ({#outcomes})`
					else "Add items to see the possible results",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Outcomes = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, 160),
				Size = UDim2.new(1, 0, 1, -(160 + 52)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.colors.stroke,
			}, outcomeRows),
			Result = if result
				then e("Frame", {
					Position = UDim2.fromOffset(0, 160),
					Size = UDim2.new(1, 0, 1, -(160 + 52)),
					BackgroundColor3 = Theme.colors.panel,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, {
					Corner = e("UICorner", { CornerRadius = Theme.radius }),
					Thumb = e("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 10),
						Size = UDim2.fromOffset(110, 110),
						BackgroundTransparency = 1,
						Image = ItemRegistry.thumbnail(result.assetId, 420),
						ZIndex = 3,
					}),
					Name = e(Text, {
						Position = UDim2.fromOffset(0, 124),
						Size = UDim2.new(1, 0, 0, 20),
						Text = resultInfo and resultInfo.name or "Unknown",
						TextSize = 16,
						TextColor3 = ItemRegistry.tier(result.assetId).color,
						TextXAlignment = Enum.TextXAlignment.Center,
						display = true,
						ZIndex = 3,
					}),
					Sub = e(Text, {
						Position = UDim2.fromOffset(0, 146),
						Size = UDim2.new(1, 0, 0, 16),
						Text = `{Format.cash(ItemRegistry.baseValue(result.assetId))}  ·  float {Format.float(
							result.float
						)}`,
						TextSize = 12,
						TextColor3 = Theme.colors.textDim,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 3,
					}),
				})
				else nil,
			Go = e(Button, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				size = UDim2.new(1, 0, 0, 42),
				text = if result then "Inspect your new item" elseif pending then "Trading up..." else "Trade up",
				textSize = 18,
				color = Theme.colors.good,
				disabled = pending or (not result and not full),
				onClick = function()
					if result then
						props.onInspect(result.uid)
						setResult(nil)
					else
						tradeUp()
					end
				end,
			}),
		}),
	})
end

return TradeUpPage
