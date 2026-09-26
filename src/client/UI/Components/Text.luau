local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Screen = require(script.Parent.Parent.Parent.Controllers.Screen)

-- on phones the ui draws at about 0.6x, so the smallest labels get bumped up to stay readable
local COMPACT_MIN_SIZE = 12

local OWN_PROPS = {
	weight = true,
	display = true,
	children = true,
}

local function Text(props)
	local hostProps = {
		BackgroundTransparency = 1,
		FontFace = if props.display then Theme.display(props.weight) else Theme.font(props.weight),
		TextColor3 = Theme.colors.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props do
		if not OWN_PROPS[key] then
			hostProps[key] = value
		end
	end
	if Screen.get().compact and type(hostProps.TextSize) == "number" and hostProps.TextSize < COMPACT_MIN_SIZE then
		hostProps.TextSize = COMPACT_MIN_SIZE
	end
	if props.display and type(hostProps.Text) == "string" then
		hostProps.Text = string.upper(hostProps.Text)
	end
	return React.createElement("TextLabel", hostProps, props.children)
end

return Text
