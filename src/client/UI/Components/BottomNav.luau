-- bottom navigation. the main tabs sit in one dock in the middle, ordered by what you do: open cases, play games,
-- look at what you got, track your season. settings (and admin for admins) are utilities, so they get their own
-- smaller dock in the bottom right, away from the wallet in the bottom left. each tab has an accent color: a
-- dot next to the label, and a bar under it while its window is open.
-- props: page (open window id or nil), onNavigate(id?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local useIsAdmin = require(script.Parent.Parent.Hooks.useIsAdmin)

local e = React.createElement

-- same height as the wallet card so the two line up
local DOCK_HEIGHT = 56
local DOCK_PADDING = 6
local BUTTON_HEIGHT = DOCK_HEIGHT - DOCK_PADDING * 2
local MAIN_WIDTH = 128
local UTILITY_WIDTH = 104
local EDGE = 16

local MAIN_TABS = {
	{ id = "cases", text = "Cases", color = Color3.fromRGB(245, 185, 28) },
	{ id = "games", text = "Games", color = Color3.fromRGB(235, 95, 95) },
	{ id = "inventory", text = "Inventory", color = Color3.fromRGB(90, 160, 255) },
	{ id = "season", text = "Season", color = Color3.fromRGB(180, 110, 255) },
}
local SETTINGS_TAB = { id = "settings", text = "Settings", color = Color3.fromRGB(160, 170, 180) }
local ADMIN_TAB = { id = "admin", text = "Admin", color = Color3.fromRGB(90, 235, 120) }

local function NavButton(props)
	local hovered, setHovered = React.useState(false)
	local tab = props.tab
	local active = props.active
	local lit = active or hovered

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(props.width, BUTTON_HEIGHT),
		BackgroundColor3 = if active then Theme.colors.panelLight else Theme.colors.panel,
		BackgroundTransparency = if active then 0 elseif hovered then 0.3 else 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
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
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Dot = e("Frame", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = tab.color,
				BackgroundTransparency = if lit then 0 else 0.45,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Label = e("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = string.upper(tab.text),
				FontFace = Theme.display(Enum.FontWeight.Medium),
				TextSize = props.textSize,
				TextColor3 = if lit then Theme.colors.text else Theme.colors.textDim,
			}),
		}),
		Underline = active and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -24, 0, 2),
			BackgroundColor3 = tab.color,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}) or nil,
	})
end

local function Dock(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, DOCK_PADDING),
			PaddingBottom = UDim.new(0, DOCK_PADDING),
			PaddingLeft = UDim.new(0, DOCK_PADDING),
			PaddingRight = UDim.new(0, DOCK_PADDING),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.fromOffset(0, DOCK_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.colors.topbar,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, children)
end

local function BottomNav(props)
	local isAdmin = useIsAdmin()

	local function toggle(id: string)
		props.onNavigate(if props.page == id then nil else id)
	end

	local function button(tab, layoutOrder: number, width: number, textSize: number)
		return e(NavButton, {
			layoutOrder = layoutOrder,
			tab = tab,
			width = width,
			textSize = textSize,
			active = props.page == tab.id,
			onClick = function()
				toggle(tab.id)
			end,
		})
	end

	local main = {}
	for index, tab in MAIN_TABS do
		main[tab.id] = button(tab, index, MAIN_WIDTH, 18)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Main = e(Dock, {
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -14),
		}, main),
		Utility = e(Dock, {
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -EDGE, 1, -14),
		}, {
			Settings = button(SETTINGS_TAB, 1, UTILITY_WIDTH, 15),
			Admin = if isAdmin then button(ADMIN_TAB, 2, UTILITY_WIDTH, 15) else nil,
		}),
	})
end

return BottomNav
