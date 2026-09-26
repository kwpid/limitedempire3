local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CaseRegistry = require(ReplicatedStorage.Shared.Cases.CaseRegistry)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local Grid = require(script.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Components.ItemTile)

local e = React.createElement

local function CasesPage(props)
	local tiles = {}
	for index, case in CaseRegistry.list() do
		local affordable = props.cash >= case.price
		tiles[case.id] = e(ItemTile, {
			id = case.id,
			layoutOrder = index,
			assetId = case.iconAssetId,
			title = case.name,
			subtitle = Format.cash(case.price),
			subtitleColor = if affordable then Theme.colors.cash else Theme.colors.bad,
			accent = case.color,
			tagText = `{#case.items - case.specialCount} items`,
			tagColor = Theme.colors.textDim,
			onSelect = props.onSelect,
		})
	end

	return e(Grid, {
		cellSize = UDim2.fromOffset(180, 212),
		cellPadding = UDim2.fromOffset(8, 8),
	}, tiles)
end

return React.memo(CasesPage)
