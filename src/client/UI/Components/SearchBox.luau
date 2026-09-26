local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

local function SearchBox(props)
	local focused, setFocused = React.useState(false)
	local hasText = props.value ~= nil and props.value ~= ""

	return e("Frame", {
		Size = props.size,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if focused then Theme.colors.strokeLight else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Input = e("TextBox", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, if hasText then -38 else -16, 1, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Text = props.value or "",
			PlaceholderText = props.placeholder or "Search...",
			PlaceholderColor3 = Theme.colors.textFaint,
			TextColor3 = Theme.colors.text,
			FontFace = Theme.font(Enum.FontWeight.Medium),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[React.Change.Text] = function(box: TextBox)
				if box.Text ~= props.value then
					props.onChange(box.Text)
				end
			end,
			[React.Event.Focused] = function()
				setFocused(true)
			end,
			[React.Event.FocusLost] = function()
				setFocused(false)
			end,
		}),
		Clear = hasText and e("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Text = "X",
			FontFace = Theme.display(Enum.FontWeight.Medium),
			TextSize = 14,
			TextColor3 = Theme.colors.textDim,
			[React.Event.Activated] = function()
				props.onChange("")
			end,
		}) or nil,
	})
end

return SearchBox
