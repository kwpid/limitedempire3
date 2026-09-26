local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CaseRegistry = require(ReplicatedStorage.Shared.Cases.CaseRegistry)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local SeriesRegistry = require(ReplicatedStorage.Shared.Series.SeriesRegistry)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Components.ItemTile)
local SpecialTile = require(script.Parent.Parent.Components.SpecialTile)
local Preloader = require(script.Parent.Parent.Parent.Controllers.Preloader)

local e = React.createElement

local FOOTER = 72
local UNLOCK_WIDTH = 210
local AUTO_WIDTH = 96
local HEADER = 30
local PAGE_SIZE = 36

local function CaseDetails(props)
	local case = CaseRegistry.get(props.caseId)
	local page, setPage = React.useState(1)

	React.useLayoutEffect(function()
		setPage(1)
		Preloader.preloadCase(props.caseId)
	end, { props.caseId })

	local regular = React.useMemo(function()
		local list = {}
		if case then
			for _, item in case.items do
				if not item.special then
					table.insert(list, item)
				end
			end
		end
		return list
	end, { props.caseId })

	if not case then
		return nil
	end

	local affordable = props.cash >= case.price
	local seriesNames = {}
	for _, seriesId in case.series do
		table.insert(seriesNames, SeriesRegistry.name(seriesId))
	end
	local seriesText = "Series: " .. table.concat(seriesNames, ", ")
	local pageCount = math.max(1, math.ceil(#regular / PAGE_SIZE))
	local currentPage = math.clamp(page, 1, pageCount)
	local first = (currentPage - 1) * PAGE_SIZE + 1
	local last = math.min(#regular, currentPage * PAGE_SIZE)

	local tiles = {}
	if case.specialCount > 0 then
		tiles.Special = e(SpecialTile, {
			layoutOrder = 0,
			subtitle = Format.percent(case.specialChance),
		})
	end
	for index = first, last do
		local item = regular[index]
		local tier = ItemRegistry.tier(item.assetId)
		tiles[tostring(item.assetId)] = e(ItemTile, {
			layoutOrder = index,
			assetId = item.assetId,
			subtitle = Format.cash(item.value),
			tagText = Format.percent(item.chance),
			tagColor = tier.color,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Caption = e(Text, {
			Size = UDim2.new(1, -340, 0, HEADER),
			Text = `{seriesText}  ·  {#regular} items + ★ rare special items`,
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
		}),
		Pager = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(330, HEADER),
			BackgroundTransparency = 1,
		}, {
			Prev = e(Button, {
				size = UDim2.fromOffset(80, HEADER),
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
				Size = UDim2.new(0, 150, 1, 0),
				Text = `Page {currentPage} / {pageCount}`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Next = e(Button, {
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(80, HEADER),
				text = "Next",
				textSize = 14,
				disabled = currentPage >= pageCount,
				onClick = function()
					setPage(currentPage + 1)
				end,
			}),
		}),
		Contents = e(Grid, {
			position = UDim2.fromOffset(0, HEADER + 8),
			size = UDim2.new(1, 0, 1, -(FOOTER + HEADER + 20)),
			cellSize = UDim2.fromOffset(152, 178),
			cellPadding = UDim2.fromOffset(6, 6),
		}, tiles),
		Footer = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, FOOTER),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Icon = e("ImageLabel", {
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.fromOffset(60, 60),
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(case.iconAssetId, 150),
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(82, 12),
				Size = UDim2.new(1, -(82 + UNLOCK_WIDTH + AUTO_WIDTH + 190), 0, 24),
				Text = case.name,
				TextSize = 20,
				display = true,
			}),
			Info = e(Text, {
				Position = UDim2.fromOffset(82, 38),
				Size = UDim2.new(1, -(82 + UNLOCK_WIDTH + AUTO_WIDTH + 190), 0, 18),
				Text = `Avg. unbox {Format.cash(case.expectedValue)}   ·   ★ Rare special item {Format.percent(case.specialChance)}   ·   Odds shown per item`,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Price = e(Text, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(UNLOCK_WIDTH + AUTO_WIDTH + 34), 0.5, 0),
				Size = UDim2.fromOffset(160, 30),
				Text = Config.Currency.Symbol .. Format.commas(case.price),
				TextSize = 22,
				TextColor3 = affordable and Theme.colors.cash or Theme.colors.bad,
				TextXAlignment = Enum.TextXAlignment.Right,
				display = true,
			}),
			Auto = e(Button, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -(UNLOCK_WIDTH + 18), 0.5, 0),
				size = UDim2.fromOffset(AUTO_WIDTH, 46),
				text = if props.autoOpen then "Auto: On" else "Auto: Off",
				textSize = 16,
				color = if props.autoOpen then Theme.colors.accent else nil,
				onClick = props.onToggleAuto,
			}),
			Unlock = e(Button, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -12, 0.5, 0),
				size = UDim2.fromOffset(UNLOCK_WIDTH, 46),
				text = if props.busy
					then "Unlocking..."
					elseif not affordable then `Not enough {Config.Currency.Name}`
					elseif props.autoOpen then "Auto Unlock"
					else "Unlock Case",
				textSize = 20,
				color = Theme.colors.good,
				disabled = props.busy or not affordable,
				onClick = function()
					props.onOpen(case.id)
				end,
			}),
		}),
	})
end

return React.memo(CaseDetails)
