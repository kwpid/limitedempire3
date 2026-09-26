local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)
local Theme = require(script.Parent.Parent.Theme)
local clock = require(script.Parent.Parent.Clock)

local e = React.createElement

local RAINBOW_STOPS = 6

local function rainbowAt(shift: number): ColorSequence
	local keypoints = {}
	for i = 0, RAINBOW_STOPS do
		local hue = (i / RAINBOW_STOPS + shift) % 1
		table.insert(keypoints, ColorSequenceKeypoint.new(i / RAINBOW_STOPS, Color3.fromHSV(hue, 0.65, 1)))
	end
	return ColorSequence.new(keypoints)
end

local function gradientFor(style: NameStyles.NameStyle)
	if style.animation == "rainbow" then
		return e("UIGradient", {
			Color = clock:map(function(t)
				return rainbowAt((t * style.speed) % 1)
			end),
		})
	end
	if not style.gradient then
		return nil
	end
	if style.animation == "shimmer" then
		return e("UIGradient", {
			Color = style.gradient,
			Offset = clock:map(function(t)
				return Vector2.new(((t * style.speed) % 1) * 2.4 - 1.2, 0)
			end),
		})
	end
	return e("UIGradient", { Color = style.gradient })
end

local function NameLabel(props)
	local style = NameStyles.get(props.styleId)

	return e("TextLabel", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		Text = props.text,
		FontFace = Theme.display(Enum.FontWeight.Bold),
		TextSize = props.textSize or 20,
		TextColor3 = style.color,
		TextStrokeTransparency = props.strokeTransparency or 0.55,
		TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, {
		Gradient = gradientFor(style),
	})
end

return React.memo(NameLabel)
