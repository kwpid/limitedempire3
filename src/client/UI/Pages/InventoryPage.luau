local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local ConfirmButton = require(script.Parent.Parent.Components.ConfirmButton)
local Grid = require(script.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Components.ItemTile)
local ItemDetails = require(script.Parent.Parent.Components.ItemDetails)
local SearchBox = require(script.Parent.Parent.Components.SearchBox)
local Dropdown = require(script.Parent.Parent.Components.Dropdown)
local InventoryFilters = require(script.Parent.InventoryFilters)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local PANEL_WIDTH = 280
local PAGE_SIZE = 30
local PAGER_HEIGHT = 32
local TOOLBAR_HEIGHT = 32
local RARITY_WIDTH = 132
local SHOW_WIDTH = 150
local SORT_WIDTH = 150

local function buildEntries(inventory)
	local list = {}
	for _, item in inventory do
		local value = Valuation.value(item)
		table.insert(list, {
			item = item,
			value = value,
			valueText = Format.cash(value),
			tierId = ItemRegistry.tier(item.assetId).id,
			traits = Traits.of(item),
		})
	end
	return list
end

local function InventoryPage(props)
	local state = { inventory = props.inventory, equipped = props.equipped, pinned = props.pinned or {} }
	local selectedUid, setSelectedUid = React.useState(nil)
	local pending, setPending = React.useState(false)
	local page, setPage = React.useState(1)
	local query, setQuery = React.useState("")
	local rarity, setRarity = React.useState("all")
	local show, setShow = React.useState("all")
	local sort, setSort = React.useState("value_desc")

	local allEntries = React.useMemo(function()
		return buildEntries(state.inventory)
	end, { state.inventory })

	local equippedSet = React.useMemo(function()
		local set = {}
		for _, uid in state.equipped do
			set[uid] = true
		end
		return set
	end, { state.equipped })

	local pinnedSet = React.useMemo(function()
		local set = {}
		for _, uid in state.pinned do
			set[uid] = true
		end
		return set
	end, { state.pinned })

	local entries = React.useMemo(function()
		return InventoryFilters.apply(
			allEntries,
			{ query = query, rarity = rarity, show = show, sort = sort },
			equippedSet,
			pinnedSet
		)
	end, { allEntries, equippedSet, pinnedSet, query, rarity, show, sort } :: { any })

	React.useLayoutEffect(function()
		setPage(1)
	end, { query, rarity, show, sort })

	local filtered = query ~= "" or rarity ~= "all" or show ~= "all"

	local selected = selectedUid and state.inventory[selectedUid]

	local function run(action)
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = action()
			setPending(false)
			if not result.ok then
				Sfx.play("error")
				Notifications.push(result.err or "Something went wrong", Theme.colors.bad)
			end
		end)
	end

	local pageCount = math.max(1, math.ceil(#entries / PAGE_SIZE))
	local currentPage = math.clamp(page, 1, pageCount)
	local first = (currentPage - 1) * PAGE_SIZE + 1
	local last = math.min(#entries, currentPage * PAGE_SIZE)

	local tiles = {}
	for index = first, last do
		local entry = entries[index]
		local item = entry.item
		local band = Condition.fromFloat(item.float)
		local equipped = equippedSet[item.uid] == true
		tiles[item.uid] = e(ItemTile, {
			id = item.uid,
			layoutOrder = index,
			assetId = item.assetId,
			subtitle = entry.valueText,
			selected = item.uid == selectedUid,
			traits = entry.traits,
			tagText = band.name,
			tagColor = band.color,
			equipped = equipped,
			pinned = pinnedSet[item.uid] == true,
			trackerCount = item.tracker and item.tracker.opens or nil,
			onSelect = setSelectedUid,
		})
	end

	local panelChildren
	if selected then
		local equipped = equippedSet[selected.uid] == true
		local pinned = pinnedSet[selected.uid] == true
		local equippable = ItemRegistry.isEquippable(selected.assetId)
		local sellValue = math.floor(Valuation.value(selected) * Config.SellRate)
		panelChildren = {
			Details = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -90),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, {
				Padding = e("UIPadding", { PaddingRight = UDim.new(0, 6) }),
				Content = e(ItemDetails, { item = selected, thumbnailSize = 120 }),
			}),
			Buttons = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 82),
				BackgroundTransparency = 1,
			}, {
				Inspect = e(Button, {
					size = UDim2.new(1, -86, 0, 38),
					text = "Inspect",
					color = Theme.colors.accent,
					onClick = function()
						props.onInspect(selected.uid)
					end,
				}),
				Pin = e(Button, {
					anchorPoint = Vector2.new(1, 0),
					position = UDim2.fromScale(1, 0),
					size = UDim2.fromOffset(80, 38),
					text = if pinned then "Unpin" else "Pin",
					color = if pinned then Theme.colors.marker:Lerp(Theme.colors.panel, 0.45) else nil,
					disabled = pending,
					onClick = function()
						local uid = selected.uid
						run(function()
							return Actions.setPinned(uid, not pinned)
						end)
					end,
				}),
				Equip = e(Button, {
					position = UDim2.fromOffset(0, 44),
					size = UDim2.new(0.5, -3, 0, 38),
					text = if not equippable then "Can't wear" elseif equipped then "Unequip" else "Equip",
					disabled = pending or not equippable,
					sound = "equip",
					onClick = function()
						run(function()
							return Actions.toggleEquipped(selected.uid)
						end)
					end,
				}),
				Sell = e(ConfirmButton, {
					anchorPoint = Vector2.new(1, 0),
					position = UDim2.new(1, 0, 0, 44),
					size = UDim2.new(0.5, -3, 0, 38),
					text = `Sell {Format.cash(sellValue)}`,
					confirmText = "Confirm sell",
					holdSeconds = if sellValue >= Config.SellHoldValue then Config.SellHoldSeconds else 0,
					resetKey = selected.uid,
					textSize = 14,
					disabled = pending,
					onConfirm = function()
						local uid = selected.uid
						run(function()
							local result = Actions.sell({ uid })
							if result.ok then
								Sfx.play("sell")
								setSelectedUid(nil)
							end
							return result
						end)
					end,
				}),
			}),
		}
	else
		panelChildren = {
			Empty = e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = next(state.inventory) and "Select an item" or "Your inventory is empty.\nOpen a case to get started.",
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.None,
				TextWrapped = true,
			}),
		}
	end
	panelChildren.Corner = e("UICorner", { CornerRadius = Theme.radius })
	panelChildren.Stroke = e("UIStroke", { Color = Theme.colors.stroke })
	panelChildren.Padding = e("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Toolbar = e("Frame", {
			Size = UDim2.new(1, -(PANEL_WIDTH + 16), 0, TOOLBAR_HEIGHT),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Search = e(SearchBox, {
				layoutOrder = 1,
				size = UDim2.new(1, -(RARITY_WIDTH + SHOW_WIDTH + SORT_WIDTH + 18), 1, 0),
				value = query,
				placeholder = "Search name, trait, series, #serial...",
				onChange = setQuery,
			}),
			Rarity = e(Dropdown, {
				layoutOrder = 2,
				size = UDim2.new(0, RARITY_WIDTH, 1, 0),
				label = "Rarity",
				options = InventoryFilters.rarities,
				value = rarity,
				onChange = setRarity,
			}),
			Show = e(Dropdown, {
				layoutOrder = 3,
				size = UDim2.new(0, SHOW_WIDTH, 1, 0),
				label = "Show",
				options = InventoryFilters.shows,
				value = show,
				onChange = setShow,
			}),
			Sort = e(Dropdown, {
				layoutOrder = 4,
				size = UDim2.new(0, SORT_WIDTH, 1, 0),
				label = "Sort",
				options = InventoryFilters.sorts,
				value = sort,
				onChange = setSort,
			}),
		}),
		Items = e(Grid, {
			position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + 8),
			size = UDim2.new(1, -(PANEL_WIDTH + 16), 1, -(PAGER_HEIGHT + TOOLBAR_HEIGHT + 16)),
			cellSize = UDim2.fromOffset(124, 160),
			cellPadding = UDim2.fromOffset(6, 6),
		}, tiles),
		NoResults = if filtered and #entries == 0
			then e(Text, {
				Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + 8),
				Size = UDim2.new(1, -(PANEL_WIDTH + 16), 0, 60),
				Text = "No items match these filters",
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			else nil,
		Pager = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -(PANEL_WIDTH + 16), 0, PAGER_HEIGHT),
			BackgroundTransparency = 1,
		}, {
			Prev = e(Button, {
				size = UDim2.fromOffset(90, PAGER_HEIGHT),
				text = "Prev",
				textSize = 14,
				disabled = currentPage <= 1,
				onClick = function()
					setPage(currentPage - 1)
				end,
			}),
			Label = e(Text, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0, 220, 1, 0),
				Text = if filtered
					then `Page {currentPage} / {pageCount}   ·   {#entries} of {#allEntries} items`
					else `Page {currentPage} / {pageCount}   ·   {#entries} items`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Next = e(Button, {
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(90, PAGER_HEIGHT),
				text = "Next",
				textSize = 14,
				disabled = currentPage >= pageCount,
				onClick = function()
					setPage(currentPage + 1)
				end,
			}),
		}),
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, panelChildren),
	})
end

return React.memo(InventoryPage)
