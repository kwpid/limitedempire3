-- a row of tabs with a marker under the active one. props: tabs = { { id, text } }, value, onChange(id),
-- size, position

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local TAB_WIDTH = 130

local function Tab(props)
	local hovered, setHovered = React.useState(false)
	local active = props.active
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(0, TAB_WIDTH, 1, 0),
		BackgroundColor3 = if active
			then Theme.colors.panelLight
			elseif hovered then Theme.colors.panel
			else Theme.colors.inset,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = string.upper(props.text),
		FontFace = Theme.display(Enum.FontWeight.Medium),
		TextSize = 15,
		TextColor3 = if active or hovered then Theme.colors.text else Theme.colors.textDim,
		[React.Event.Activated] = function()
			if not active then
				Sfx.play("tab")
				props.onClick()
			end
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
			Color = if active then Theme.colors.strokeLight else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Marker = active and e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Theme.colors.marker,
			BorderSizePixel = 0,
		}) or nil,
	})
end

local function TabBar(props)
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tab in props.tabs do
		children[tab.id] = e(Tab, {
			layoutOrder = index,
			text = tab.text,
			active = props.value == tab.id,
			onClick = function()
				props.onChange(tab.id)
			end,
		})
	end
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		BackgroundTransparency = 1,
	}, children)
end

return TabBar
