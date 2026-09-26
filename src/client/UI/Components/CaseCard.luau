-- a case on the cases page: the case color glowing up from the bottom, its icon, name, price and the best item
-- you can see in it, plus a Starter tag on cases with a lower house edge, a star to favorite it, and the item a search
-- matched in it. props: case, cash, layoutOrder, onSelect(caseId), favorite?, onFavorite?(caseId), match? (text)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local Tiers = require(ReplicatedStorage.Shared.Items.Tiers)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local CaseIcon = require(script.Parent.CaseIcon)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local GLOW_IDLE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.35, 1),
	NumberSequenceKeypoint.new(1, 0.55),
})
local GLOW_HOVER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.9),
	NumberSequenceKeypoint.new(1, 0.35),
})

local function CaseCard(props)
	local case = props.case
	local hovered, setHovered = React.useState(false)
	local affordable = props.cash >= case.price
	local topTier = Tiers.fromValue(case.topValue)

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onSelect(case.id)
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Color = if hovered then case.color else Theme.colors.stroke,
			Transparency = if hovered then 0.2 else 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Glow = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = case.color,
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = if hovered then GLOW_HOVER else GLOW_IDLE,
			}),
		}),
		Icon = e(CaseIcon, {
			case = case,
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, if hovered then 12 else 16),
			size = UDim2.fromOffset(112, 112),
			zIndex = 2,
		}),
		Name = e(Text, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -76),
			Size = UDim2.new(1, -16, 0, 22),
			Text = case.name,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
			ZIndex = 2,
		}),
		Starter = case.houseEdge < Config.HouseEdge and e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.colors.good,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
			Label = e(Text, {
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = "Starter",
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.None,
				display = true,
				ZIndex = 4,
			}),
		}) or nil,
		Star = props.onFavorite and e("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = if props.favorite then "★" else "☆",
			FontFace = Theme.font(Enum.FontWeight.Bold),
			TextSize = 22,
			TextColor3 = if props.favorite then Theme.colors.marker elseif hovered then Theme.colors.text else Theme.colors.textFaint,
			TextStrokeTransparency = 0.6,
			ZIndex = 4,
			[React.Event.Activated] = function()
				Sfx.play("tab")
				props.onFavorite(case.id)
			end,
		}) or nil,
		Match = props.match and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 112),
			Size = UDim2.new(1, -16, 0, 20),
			BackgroundColor3 = Theme.colors.topbar,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Label = e(Text, {
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -12, 1, 0),
				Text = `Has: {props.match}`,
				TextSize = 11,
				TextColor3 = Theme.colors.cash,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 4,
			}),
		}) or nil,
		Best = e(Text, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -52),
			Size = UDim2.new(1, -16, 0, 14),
			Text = `Up to {Format.cash(case.topValue)}  +  ★`,
			TextSize = 11,
			TextColor3 = topTier.color,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		}),
		Price = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 26),
			BackgroundColor3 = Theme.colors.topbar,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if affordable then Theme.colors.cash else Theme.colors.bad,
				Transparency = 0.6,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Label = e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = Format.cash(case.price),
				TextSize = 15,
				TextColor3 = if affordable then Theme.colors.cash else Theme.colors.bad,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				ZIndex = 3,
			}),
		}),
	})
end

return React.memo(CaseCard)
