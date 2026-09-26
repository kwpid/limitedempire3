local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)

local e = React.createElement

local function SpecialTile(props)
	local gold = Theme.colors.special

	return e("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = gold,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Glow = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = gold,
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.85),
					NumberSequenceKeypoint.new(1, 0.45),
				}),
			}),
		}),
		Star = e(Text, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, if props.compact then 0.45 else 0.38),
			Size = UDim2.fromScale(1, 0.5),
			Text = "★",
			TextScaled = true,
			TextColor3 = gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			ZIndex = 2,
		}, {
			Limit = e("UITextSizeConstraint", { MaxTextSize = if props.compact then 56 else 64 }),
		}),
		Title = not props.compact and e(Text, {
			Position = UDim2.new(0, 8, 1, -44),
			Size = UDim2.new(1, -16, 0, 16),
			Text = "Rare Special Item",
			TextSize = 13,
			TextColor3 = gold,
			weight = Enum.FontWeight.Bold,
			ZIndex = 2,
		}) or nil,
		Subtitle = not props.compact and props.subtitle and e(Text, {
			Position = UDim2.new(0, 8, 1, -26),
			Size = UDim2.new(1, -16, 0, 14),
			Text = props.subtitle,
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
			ZIndex = 2,
		}) or nil,
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = gold,
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
	})
end

return React.memo(SpecialTile)
