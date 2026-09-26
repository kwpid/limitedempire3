-- the cases list, one section per case series (CaseData.caseSeries): a colored header with the series name,
-- description and price range, then that series' cases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CaseRegistry = require(ReplicatedStorage.Shared.Cases.CaseRegistry)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local CaseCard = require(script.Parent.Parent.Components.CaseCard)

local e = React.createElement

local CARD_SIZE = UDim2.fromOffset(176, 214)
local CARD_GAP = 8
local HEADER_HEIGHT = 44

local function Section(props)
	local group = props.group
	local low, high = math.huge, 0
	local cards = {
		Layout = e("UIGridLayout", {
			CellSize = CARD_SIZE,
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, case in group.cases do
		low = math.min(low, case.price)
		high = math.max(high, case.price)
		cards[case.id] = e(CaseCard, {
			layoutOrder = index,
			case = case,
			cash = props.cash,
			onSelect = props.onSelect,
		})
	end
	local priceText = if low == high then Format.cash(low) else `{Format.cash(low)} - {Format.cash(high)}`

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Accent = e("Frame", {
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = group.color,
				BorderSizePixel = 0,
			}),
			Fade = e("Frame", {
				Size = UDim2.fromScale(0.5, 1),
				BackgroundColor3 = group.color,
				BorderSizePixel = 0,
			}, {
				Gradient = e("UIGradient", { Transparency = NumberSequence.new(0.82, 1) }),
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(16, 4),
				Size = UDim2.new(0.6, 0, 0, 22),
				Text = group.name,
				TextSize = 20,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Description = e(Text, {
				Position = UDim2.fromOffset(16, 25),
				Size = UDim2.new(0.7, 0, 0, 14),
				Text = group.description,
				TextSize = 11,
				TextColor3 = Theme.colors.textDim,
			}),
			Info = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.3, 0, 1, 0),
				Text = `{#group.cases} {if #group.cases == 1 then "case" else "cases"}   ·   {priceText}`,
				TextSize = 12,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		Cards = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, cards),
	})
end

local function CasesPage(props)
	local sections = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	}
	for index, group in CaseRegistry.caseSeries() do
		local shown = table.clone(group)
		shown.cases = {}
		for _, case in group.cases do
			if CaseRegistry.isAvailable(case) then
				table.insert(shown.cases, case)
			end
		end
		if #shown.cases == 0 then
			continue
		end
		sections[group.id] = e(Section, {
			layoutOrder = index,
			group = shown,
			cash = props.cash,
			onSelect = props.onSelect,
		})
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, sections)
end

return React.memo(CasesPage)
