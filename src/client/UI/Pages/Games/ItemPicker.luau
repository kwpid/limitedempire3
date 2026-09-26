-- a searchable grid of the player's items that can be used in a game (not equipped, pinned or custom), used by the
-- upgrader and trade-up. props: inventory, equipped, pinned, selected ({ [uid]: true }), onToggle(uid),
-- filter(item) -> boolean (optional extra rule), sort ("value_desc" | "value_asc"), title, size, position,
-- cellSize, emptyText

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Parent.Components.ItemTile)
local SearchBox = require(script.Parent.Parent.Parent.Components.SearchBox)

local e = React.createElement

local MAX_SHOWN = 120

local function ItemPicker(props)
	local query, setQuery = React.useState("")

	local usable = React.useMemo(function()
		local blocked = {}
		for _, uid in props.equipped or {} do
			blocked[uid] = true
		end
		for _, uid in props.pinned or {} do
			blocked[uid] = true
		end
		local list = {}
		for uid, item in props.inventory do
			if not blocked[uid] and not ItemRegistry.isCustom(item.assetId) then
				local info = ItemRegistry.get(item.assetId)
				table.insert(list, {
					item = item,
					value = Valuation.value(item),
					name = string.lower(info and info.name or ""),
				})
			end
		end
		local ascending = props.sort == "value_asc"
		table.sort(list, function(a, b)
			if a.value == b.value then
				return a.item.uid < b.item.uid
			end
			return if ascending then a.value < b.value else a.value > b.value
		end)
		return list
	end, { props.inventory, props.equipped, props.pinned, props.sort } :: { any })

	local needle = string.lower(query)
	local tiles = {}
	local shown = 0
	for index, entry in usable do
		if shown >= MAX_SHOWN then
			break
		end
		if props.filter and not props.filter(entry.item) then
			continue
		end
		if needle ~= "" and not string.find(entry.name, needle, 1, true) then
			continue
		end
		shown += 1
		local item = entry.item
		local band = Condition.fromFloat(item.float)
		tiles[item.uid] = e(ItemTile, {
			id = item.uid,
			layoutOrder = index,
			assetId = item.assetId,
			subtitle = Format.cash(entry.value),
			selected = props.selected[item.uid] == true,
			traits = Traits.of(item),
			tagText = band.name,
			tagColor = band.color,
			onSelect = props.onToggle,
		})
	end

	return e("Frame", {
		Size = props.size,
		Position = props.position,
		BackgroundTransparency = 1,
	}, {
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 18),
			Text = props.title or "Your items",
			TextSize = 15,
			display = true,
		}),
		Search = e(SearchBox, {
			position = UDim2.fromOffset(0, 24),
			size = UDim2.new(1, 0, 0, 28),
			value = query,
			placeholder = "Search your items...",
			onChange = setQuery,
		}),
		Items = e(Grid, {
			position = UDim2.fromOffset(0, 60),
			size = UDim2.new(1, 0, 1, -60),
			cellSize = props.cellSize or UDim2.fromOffset(92, 118),
			cellPadding = UDim2.fromOffset(5, 5),
		}, tiles),
		Empty = if shown == 0
			then e(Text, {
				Position = UDim2.fromOffset(0, 66),
				Size = UDim2.new(1, 0, 0, 40),
				Text = props.emptyText or "No usable items. Equipped, pinned and custom items can't be used.",
				TextSize = 12,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
			})
			else nil,
	})
end

return ItemPicker
