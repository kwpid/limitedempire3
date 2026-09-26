-- a case on the cases page: the case color glowing up from the bottom, its icon, name, price and the best item
-- you can see in it. props: case, cash, layoutOrder, onSelect(caseId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Format = require(ReplicatedStorage.Shared.Util.Format)
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
