-- a round badge with a checkmark drawn from two bars. props: position, anchorPoint, size (px, default 18), color, zIndex

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

-- stroke endpoints on an 18px badge: (4.5, 9.5) -> (7.5, 12.5) -> (13.5, 5.5)
local function Stroke(props)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(props.x / 18, props.y / 18),
		Size = UDim2.fromScale(props.length / 18, 2 / 18),
		Rotation = props.rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	})
end

local function Checkmark(props)
	local size = props.size or 18
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = props.color or Theme.colors.good,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Short = e(Stroke, { x = 6, y = 11, length = 5.2, rotation = 45, zIndex = props.zIndex }),
		Long = e(Stroke, { x = 10.5, y = 9, length = 10.2, rotation = -49.4, zIndex = props.zIndex }),
	})
end

return Checkmark
