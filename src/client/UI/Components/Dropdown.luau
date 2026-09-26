local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local Chevron = require(script.Parent.Chevron)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local OPTION_HEIGHT = 28

local function Option(props)
	local hovered, setHovered = React.useState(false)

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
		BackgroundColor3 = if props.active then Theme.colors.panelLight elseif hovered then Theme.colors.panel else Theme.colors.topbar,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 31,
		[React.Event.Activated] = props.onSelect,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Label = e(Text, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = props.label,
			TextSize = 13,
			TextColor3 = if props.color then props.color elseif props.active then Theme.colors.text else Theme.colors.textDim,
			ZIndex = 32,
		}),
	})
end

local function Dropdown(props)
	local open, setOpen = React.useState(false)
	local hovered, setHovered = React.useState(false)

	local current = props.options[1]
	for _, option in props.options do
		if option.id == props.value then
			current = option
		end
	end

	local optionChildren = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	if open then
		for index, option in props.options do
			optionChildren[option.id] = e(Option, {
				layoutOrder = index,
				label = option.label,
				color = option.color,
				active = option.id == props.value,
				onSelect = function()
					Sfx.play("tab")
					setOpen(false)
					props.onChange(option.id)
				end,
			})
		end
	end

	return e("Frame", {
		Size = props.size,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ZIndex = if open then 30 else 1,
	}, {
		Toggle = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = if open or hovered then Theme.colors.panelLight else Theme.colors.panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			[React.Event.Activated] = function()
				Sfx.play("tab")
				setOpen(not open)
			end,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if open then Theme.colors.strokeLight else Theme.colors.stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Prefix = e(Text, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = props.label,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
				TextTruncate = Enum.TextTruncate.None,
				display = true,
			}),
			Value = e(Text, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -30, 1, 0),
				Text = current and current.label or "",
				TextSize = 13,
				TextColor3 = current and current.color or Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Arrow = e(Chevron, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -8, 0.5, 0),
				up = open,
				color = if open or hovered then Theme.colors.text else Theme.colors.textDim,
			}),
		}),
		List = open and e("Frame", {
			Position = UDim2.new(0, 0, 1, 4),
			Size = UDim2.new(1, 0, 0, #props.options * OPTION_HEIGHT),
			BackgroundColor3 = Theme.colors.topbar,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 30,
		}, {
			Stroke = e("UIStroke", { Color = Theme.colors.strokeLight }),
			Options = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 30,
			}, optionChildren),
		}) or nil,
	})
end

return Dropdown
