local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local Button = require(script.Parent.Button)
local useViewportScale = require(script.Parent.Parent.Hooks.useViewportScale)

local e = React.createElement

local BASE_SIZE = Vector2.new(1000, 600)
local HEADER = 46

local function Window(props)
	local scale = useViewportScale(BASE_SIZE + Vector2.new(60, 130))

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
		Position = UDim2.new(0.5, 0, 0.5, -30),
		Size = UDim2.fromOffset(BASE_SIZE.X, BASE_SIZE.Y),
		BackgroundColor3 = Theme.colors.window,
		BorderSizePixel = 0,
		Visible = props.visible ~= false,
	}, {
		Scale = e("UIScale", { Scale = scale }),
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
				size = UDim2.fromOffset(70, 28),
				position = UDim2.new(0, 10, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				textSize = 14,
				onClick = props.onBack,
			}),
			Title = e(Text, {
				Position = UDim2.new(0, props.onBack and 94 or 16, 0, 0),
				Size = UDim2.new(1, -200, 1, 0),
				Text = props.title,
				TextSize = 20,
				display = true,
			}),
			Subtitle = props.subtitle and e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -56, 0, 0),
				Size = UDim2.new(0, 300, 1, 0),
				Text = props.subtitle,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Close = e(Button, {
				text = "X",
				size = UDim2.fromOffset(30, 28),
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
