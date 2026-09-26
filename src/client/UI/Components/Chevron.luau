-- a small chevron arrow drawn from two bars, points down by default. props: position, anchorPoint, color, up, zIndex

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

local function Bar(props)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(props.x, 4),
		Size = UDim2.fromOffset(8, 2),
		Rotation = props.rotation,
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 1) }),
	})
end

local function Chevron(props)
	local color = props.color or Theme.colors.textDim
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.fromOffset(12, 8),
		Rotation = if props.up then 180 else 0,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		Left = e(Bar, { x = 3.5, rotation = 45, color = color, zIndex = props.zIndex }),
		Right = e(Bar, { x = 8.5, rotation = -45, color = color, zIndex = props.zIndex }),
	})
end

return Chevron
