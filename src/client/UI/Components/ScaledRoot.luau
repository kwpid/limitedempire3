-- fills its parent in design units: children lay out as if the screen were (size / scale) and are drawn at scale.
-- props: scale, visible?, children

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local function ScaledRoot(props)
	local children = { Scale = e("UIScale", { Scale = props.scale }) }
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		Size = UDim2.fromScale(1 / props.scale, 1 / props.scale),
		BackgroundTransparency = 1,
		Visible = props.visible ~= false,
	}, children)
end

return ScaledRoot
