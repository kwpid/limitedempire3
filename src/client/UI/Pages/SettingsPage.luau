-- the Settings tab: sections from Shared.Settings in a list on the left, the picked section's settings as cards on the
-- right, each with a description. changes save to the server right away (ClientSettings.set), and a section can be
-- reset to its defaults. lifetime stats live in the Stats for Nerds tab (StatsPage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Settings)
local Tiers = require(Shared.Items.Tiers)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local ClientSettings = require(script.Parent.Parent.Parent.Controllers.ClientSettings)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local SIDEBAR_WIDTH = 200
local CARD_HEIGHT = 64
local WIDE_CARD_HEIGHT = 104
local HEADER_HEIGHT = 58

local function Switch(props)
	local on = props.value == true
	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(50, 26),
		BackgroundColor3 = if on then Theme.colors.good else Theme.colors.panelLight,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onChange(not on)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Knob = e("Frame", {
			AnchorPoint = Vector2.new(if on then 1 else 0, 0.5),
			Position = UDim2.new(if on then 1 else 0, if on then -3 else 3, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = Theme.colors.text,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local function Pill(props)
	local hovered, setHovered = React.useState(false)
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if props.active
			then Theme.colors.accent
			elseif hovered then Theme.colors.panelLight
			else Theme.colors.inset,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = props.label,
		FontFace = Theme.font(Enum.FontWeight.Bold),
		TextSize = 13,
		TextColor3 = props.color or (if props.active then Theme.colors.text else Theme.colors.textDim),
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
			Color = if props.active then (props.color or Theme.colors.strokeLight) else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }),
	})
end

local function pillRow(children, props)
	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.alignment or Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, children)
end

local function SettingCard(props)
	local def: Settings.Def = props.def
	local value = props.value
	local wide = def.kind == "tiers"

	local control
	if def.kind == "toggle" then
		control = e(Switch, {
			value = value,
			onChange = function(nextValue)
				ClientSettings.set(def.id, nextValue)
			end,
		})
	elseif def.kind == "choice" then
		local pills = {}
		for index, option in def.options or {} do
			pills["Option" .. index] = e(Pill, {
				layoutOrder = index,
				label = option.label,
				active = option.value == value,
				onClick = function()
					ClientSettings.set(def.id, option.value)
				end,
			})
		end
		control = pillRow(pills, {
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, 0, 0.5, 0),
			size = UDim2.new(0.5, 0, 0, 28),
		})
	elseif def.kind == "tiers" then
		local selected = if type(value) == "table" then value else {}
		local pills = {}
		for index, tierId in Settings.autoSellTiers do
			local tier = Tiers.get(tierId)
			pills[tierId] = e(Pill, {
				layoutOrder = index,
				label = tier and tier.name or tierId,
				active = table.find(selected, tierId) ~= nil,
				color = tier and tier.color,
				onClick = function()
					local nextValue = table.clone(selected)
					local at = table.find(nextValue, tierId)
					if at then
						table.remove(nextValue, at)
					else
						table.insert(nextValue, tierId)
					end
					ClientSettings.set(def.id, nextValue)
				end,
			})
		end
		control = pillRow(pills, {
			alignment = Enum.HorizontalAlignment.Left,
			position = UDim2.fromOffset(0, 52),
			size = UDim2.new(1, 0, 0, 28),
		})
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, if wide then WIDE_CARD_HEIGHT else CARD_HEIGHT),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),
		Label = e(Text, {
			Size = UDim2.new(if wide then 1 else 0.5, 0, 0, 18),
			Text = def.label,
			TextSize = 15,
			weight = Enum.FontWeight.Bold,
		}),
		Description = def.description and e(Text, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(if wide then 1 else 0.5, -8, 0, 16),
			Text = def.description,
			TextSize = 12,
			TextColor3 = Theme.colors.textFaint,
		}),
		Control = control,
	})
end

local function SectionButton(props)
	local hovered, setHovered = React.useState(false)
	local active = props.active
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = if active then Theme.colors.panelLight elseif hovered then Theme.colors.panel else Theme.colors.inset,
		BackgroundTransparency = if active or hovered then 0 else 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
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
		Marker = active and e("Frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = Theme.colors.marker,
			BorderSizePixel = 0,
		}) or nil,
		Label = e(Text, {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -44, 1, 0),
			Text = props.name,
			TextSize = 16,
			TextColor3 = if active then Theme.colors.text else Theme.colors.textDim,
			display = true,
		}),
		Count = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 30, 1, 0),
			Text = tostring(props.count),
			TextSize = 12,
			TextColor3 = Theme.colors.textFaint,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function SettingsPage()
	local settings, setSettings = React.useState(ClientSettings.all())
	local section, setSection = React.useState(Settings.sections[1])

	React.useLayoutEffect(function()
		setSettings(ClientSettings.all())
		local connection = ClientSettings.changed:Connect(setSettings)
		return function()
			connection:Disconnect()
		end
	end, {})

	local sidebar = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	}
	local defs = {}
	for index, name in Settings.sections do
		local count = 0
		for _, def in Settings.list do
			if def.section == name and not def.hidden then
				count += 1
				if name == section then
					table.insert(defs, def)
				end
			end
		end
		sidebar[name] = e(SectionButton, {
			layoutOrder = index,
			name = name,
			count = count,
			active = name == section,
			onClick = function()
				setSection(name)
			end,
		})
	end

	local cards = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	}
	for index, def in defs do
		cards[def.id] = e(SettingCard, { layoutOrder = index, def = def, value = settings[def.id] })
	end

	local info = Settings.sectionInfo[section] or {}

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Sidebar = e("Frame", {
			Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			List = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
			}, sidebar),
		}),
		Content = e("Frame", {
			Position = UDim2.fromOffset(SIDEBAR_WIDTH + 16, 0),
			Size = UDim2.new(1, -(SIDEBAR_WIDTH + 16), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Title = e(Text, {
				Size = UDim2.new(1, -180, 0, 26),
				Text = section,
				TextSize = 24,
				display = true,
			}),
			Description = e(Text, {
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, -180, 0, 18),
				Text = info.description or "",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Reset = e(Button, {
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(170, 34),
				text = "Reset section",
				textSize = 14,
				onClick = function()
					local defaults = Settings.defaults()
					for _, def in defs do
						local current = settings[def.id]
						local default = defaults[def.id]
						local same = current == default
						if type(default) == "table" and type(current) == "table" then
							same = #current == #default
						end
						if not same then
							ClientSettings.set(def.id, default)
						end
					end
				end,
			}),
			Cards = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 5,
				ScrollBarImageColor3 = Theme.colors.stroke,
			}, cards),
		}),
	})
end

return React.memo(SettingsPage)
