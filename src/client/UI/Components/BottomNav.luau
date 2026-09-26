-- bottom navigation, CS:GO style: separate slate buttons with a faint diagonal stripe pattern, a light top edge and
-- an accent bar along the bottom that lights up on hover and while the tab's window is open. Cases is the big button
-- in the middle (it is the game), with the other tabs on either side: Inventory and Games to the left, Season and
-- Settings to the right. admin stays apart in the bottom right.
-- props: page (open window id or nil), onNavigate(id?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local useIsAdmin = require(script.Parent.Parent.Hooks.useIsAdmin)

local e = React.createElement

local HEIGHT = 48
local WIDTH = 132
local FEATURED_HEIGHT = 58
local FEATURED_WIDTH = 190
local GAP = 6
local EDGE = 16

local BUTTON_COLOR = Color3.fromRGB(30, 34, 39)
local BUTTON_HOVER = Color3.fromRGB(38, 43, 49)
local BUTTON_ACTIVE = Color3.fromRGB(46, 52, 59)

local TABS = {
	{ id = "inventory", text = "Inventory", color = Color3.fromRGB(90, 160, 255) },
	{ id = "games", text = "Games", color = Color3.fromRGB(235, 95, 95) },
	{ id = "cases", text = "Cases", color = Color3.fromRGB(245, 185, 28), featured = true },
	{ id = "season", text = "Season", color = Color3.fromRGB(180, 110, 255) },
	{ id = "settings", text = "Settings", color = Color3.fromRGB(160, 170, 180) },
}
local ADMIN_TAB = { id = "admin", text = "Admin", color = Color3.fromRGB(90, 235, 120) }

-- diagonal stripes from one gradient: STRIPES hard edged bands (a gradient holds at most 20 keypoints, 4 per band)
local STRIPES = 5
local function stripes(strength: number): NumberSequence
	local period = 1 / STRIPES
	local band = period * 0.4
	local edge = 0.002
	local on, off = 1 - strength, 1
	local points = {}
	for index = 0, STRIPES - 1 do
		local start = index * period
		table.insert(points, NumberSequenceKeypoint.new(start, on))
		table.insert(points, NumberSequenceKeypoint.new(start + band, on))
		table.insert(points, NumberSequenceKeypoint.new(start + band + edge, off))
		table.insert(points, NumberSequenceKeypoint.new(if index == STRIPES - 1 then 1 else start + period - edge, off))
	end
	return NumberSequence.new(points)
end
local STRIPES_IDLE = stripes(0.035)
local STRIPES_LIT = stripes(0.07)

local function NavButton(props)
	local hovered, setHovered = React.useState(false)
	local tab = props.tab
	local active = props.active
	local lit = active or hovered
	local featured = tab.featured == true

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = if featured then UDim2.fromOffset(FEATURED_WIDTH, FEATURED_HEIGHT) else UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = if active then BUTTON_ACTIVE elseif hovered then BUTTON_HOVER else BUTTON_COLOR,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
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
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		Stroke = e("UIStroke", {
			Color = if active then tab.color else Theme.colors.stroke,
			Transparency = if active then 0.45 else 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		-- the featured button carries a faint wash of its color so it reads as the main one
		Tint = featured and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = tab.color,
			BackgroundTransparency = if lit then 0.84 else 0.9,
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(0.3, 1),
			}),
		}) or nil,
		Stripes = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = -35,
				Transparency = if lit then STRIPES_LIT else STRIPES_IDLE,
			}),
		}),
		-- light top edge, darker bottom, like a bevel
		Shade = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 0.65),
				}),
			}),
		}),
		TopEdge = e("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if lit then 0.85 else 0.92,
			BorderSizePixel = 0,
		}),
		Accent = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, if featured then 3 else 2),
			BackgroundColor3 = tab.color,
			BackgroundTransparency = if active then 0 elseif hovered then 0.25 else 0.65,
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		Label = e("TextLabel", {
			Size = UDim2.new(1, 0, 1, -2),
			BackgroundTransparency = 1,
			Text = string.upper(tab.text),
			FontFace = Theme.display(if featured then Enum.FontWeight.Bold else Enum.FontWeight.Medium),
			TextSize = if featured then 24 else 17,
			TextColor3 = if lit
				then Color3.new(1, 1, 1)
				elseif featured then tab.color:Lerp(Color3.new(1, 1, 1), 0.35)
				else Theme.colors.textDim,
			TextStrokeTransparency = 0.8,
			ZIndex = 2,
		}),
	})
end

local function BottomNav(props)
	local isAdmin = useIsAdmin()

	local function button(tab, layoutOrder: number?)
		return e(NavButton, {
			layoutOrder = layoutOrder,
			tab = tab,
			active = props.page == tab.id,
			onClick = function()
				props.onNavigate(if props.page == tab.id then nil else tab.id)
			end,
		})
	end

	local row = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tab in TABS do
		row[tab.id] = button(tab, index)
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, FEATURED_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Tabs = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, row),
		-- admin sits apart in the bottom right so it is not mixed in with the player tabs
		Admin = if isAdmin
			then e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -EDGE, 1, 0),
				Size = UDim2.fromOffset(WIDTH, HEIGHT),
				BackgroundTransparency = 1,
			}, {
				Button = button(ADMIN_TAB),
			})
			else nil,
	})
end

return BottomNav
