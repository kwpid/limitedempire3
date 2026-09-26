local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local useIsAdmin = require(script.Parent.Parent.Hooks.useIsAdmin)

local e = React.createElement

local BUTTON_WIDTH = 150
local HEIGHT = 48

local function NavButton(props)
	local hovered, setHovered = React.useState(false)
	local active = props.active

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(BUTTON_WIDTH, HEIGHT),
		BackgroundColor3 = if active
			then Theme.colors.panelLight
			elseif hovered then Theme.colors.panel
			else Theme.colors.topbar,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = string.upper(props.text),
		FontFace = Theme.display(Enum.FontWeight.Medium),
		TextSize = 18,
		TextColor3 = if active or hovered then Theme.colors.text else Theme.colors.textDim,
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onClick()
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
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Theme.colors.marker,
			BorderSizePixel = 0,
		}) or nil,
	})
end

local function BottomNav(props)
	local isAdmin = useIsAdmin()

	local tabs = {
		{ id = "cases", text = "Cases" },
		{ id = "inventory", text = "Inventory" },
		{ id = "games", text = "Games" },
		{ id = "settings", text = "Settings" },
	}

	local function toggle(id: string)
		props.onNavigate(if props.page == id then nil else id)
	end

	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tab in tabs do
		children[tab.id] = e(NavButton, {
			layoutOrder = index,
			text = tab.text,
			active = props.page == tab.id,
			onClick = function()
				toggle(tab.id)
			end,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Tabs = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, children),
		-- admin sits apart in the bottom right so it is not mixed in with the player tabs
		Admin = if isAdmin
			then e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.fromOffset(BUTTON_WIDTH, HEIGHT),
				BackgroundTransparency = 1,
			}, {
				Button = e(NavButton, {
					text = "Admin",
					active = props.page == "admin",
					onClick = function()
						toggle("admin")
					end,
				}),
			})
			else nil,
	})
end

return BottomNav
