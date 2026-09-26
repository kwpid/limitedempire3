-- a small push pin (round head and a needle, tilted) drawn from frames. props: position, anchorPoint, size (px,
-- default 14), color, zIndex

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

local function PinIcon(props)
	local size = props.size or 14
	local color = props.color or Theme.colors.marker
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = 35,
		ZIndex = props.zIndex,
	}, {
		Needle = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.new(0, 2, 0.55, 0),
			BackgroundColor3 = Theme.colors.text,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}),
		Head = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.62, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(20, 20, 20), Transparency = 0.4 }),
		}),
	})
end

return PinIcon
