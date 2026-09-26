local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local Button = require(script.Parent.Button)
local Layout = require(script.Parent.Parent.Layout)
local useScreen = require(script.Parent.Parent.Hooks.useScreen)

local e = React.createElement

local HEADER = 46

-- sizes itself with Layout.window: centered on bigger screens, filling the screen on phones
local function Window(props)
	local screen = useScreen()
	local layout = Layout.window(screen)
	-- header buttons get a bigger tap target on phones
	local buttonHeight = if screen.compact then 34 else 28

	local body = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	}
	for key, child in props.children or {} do
		body[key] = child
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, layout.offsetY),
		Size = UDim2.fromOffset(layout.size.X, layout.size.Y),
		BackgroundColor3 = Theme.colors.window,
		BorderSizePixel = 0,
		Visible = props.visible ~= false,
	}, {
		Scale = e("UIScale", { Scale = layout.scale }),
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, HEADER),
			BackgroundColor3 = Theme.colors.topbar,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Back = props.onBack and e(Button, {
				text = "Back",
				size = UDim2.fromOffset(if screen.compact then 84 else 70, buttonHeight),
				position = UDim2.new(0, 10, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				textSize = 14,
				onClick = props.onBack,
			}),
			Title = e(Text, {
				Position = UDim2.new(0, if props.onBack then (if screen.compact then 108 else 94) else 16, 0, 0),
				Size = UDim2.new(1, -200, 1, 0),
				Text = props.title,
				TextSize = 20,
				display = true,
			}),
			Subtitle = props.subtitle and e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, if screen.compact then -68 else -56, 0, 0),
				Size = UDim2.new(0, 300, 1, 0),
				Text = props.subtitle,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Close = e(Button, {
				text = "X",
				size = UDim2.fromOffset(if screen.compact then 46 else 30, buttonHeight),
				position = UDim2.new(1, -10, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				textSize = 14,
				onClick = props.onClose,
			}),
		}),
		Divider = e("Frame", {
			Position = UDim2.fromOffset(0, HEADER),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.colors.stroke,
			BorderSizePixel = 0,
		}),
		Body = e("Frame", {
			Position = UDim2.fromOffset(0, HEADER + 1),
			Size = UDim2.new(1, 0, 1, -(HEADER + 1)),
			BackgroundTransparency = 1,
		}, body),
	})
end

return Window
