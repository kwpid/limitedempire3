-- settings window: every setting from Shared.Settings grouped by section on the left, lifetime stats on the right.
-- changes save to the server right away (ClientSettings.set).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local PlayerStats = require(Shared.PlayerStats)
local Settings = require(Shared.Settings)
local Tiers = require(Shared.Items.Tiers)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local ClientSettings = require(script.Parent.Parent.Parent.Controllers.ClientSettings)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local STATS_WIDTH = 300
local ROW_HEIGHT = 52

local function Switch(props)
	local on = props.value == true
	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
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
			Size = UDim2.fromOffset(18, 18),
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
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if props.active then Theme.colors.accent elseif hovered then Theme.colors.panelLight else Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = props.label,
		FontFace = Theme.font(Enum.FontWeight.Bold),
		TextSize = 12,
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
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
end

local function pillRow(children, props)
	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.alignment or Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
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

local function SettingRow(props)
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
			size = UDim2.new(0.5, 0, 0, 26),
		})
	elseif def.kind == "tiers" then
		local selected = if type(value) == "table" then value else {}
		local pills = {}
		for index, tierId in Settings.autoSellTiers do
			local tier = Tiers.get(tierId)
			local active = table.find(selected, tierId) ~= nil
			pills[tierId] = e(Pill, {
				layoutOrder = index,
				label = tier and tier.name or tierId,
				active = active,
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
			position = UDim2.fromOffset(0, 46),
			size = UDim2.new(1, 0, 0, 26),
		})
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, if wide then ROW_HEIGHT + 32 else ROW_HEIGHT),
		BackgroundTransparency = 1,
	}, {
		Line = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.colors.stroke,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}),
		Label = e(Text, {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(if wide then 1 else 0.5, 0, 0, 18),
			Text = def.label,
			TextSize = 14,
			weight = Enum.FontWeight.Bold,
		}),
		Description = def.description and e(Text, {
			Position = UDim2.fromOffset(0, 27),
			Size = UDim2.new(if wide then 1 else 0.5, -8, 0, 16),
			Text = def.description,
			TextSize = 11,
			TextColor3 = Theme.colors.textFaint,
		}),
		Control = control,
	})
end

local function statText(stat, stats): string
	local value = stats[stat.id] or 0
	if stat.format == "cash" then
		return Format.cash(value)
	elseif stat.format == "item" then
		local info = value ~= 0 and ItemRegistry.get(value)
		return if info then info.name else "-"
	end
	return Format.commas(value)
end

local function SettingsPage(props)
	local settings, setSettings = React.useState(ClientSettings.all())

	React.useLayoutEffect(function()
		setSettings(ClientSettings.all())
		local connection = ClientSettings.changed:Connect(setSettings)
		return function()
			connection:Disconnect()
		end
	end, {})

	local rows = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 12) }),
	}
	local order = 0
	for _, section in Settings.sections do
		order += 1
		rows["Section" .. section] = e(Text, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, if order == 1 then 26 else 40),
			Text = section,
			TextSize = 17,
			TextColor3 = Theme.colors.textDim,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			display = true,
		})
		for _, def in Settings.list do
			if def.section == section then
				order += 1
				rows[def.id] = e(SettingRow, {
					layoutOrder = order,
					def = def,
					value = settings[def.id],
				})
			end
		end
	end

	local statRows = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local stats = props.stats or {}
	for index, stat in PlayerStats.list do
		statRows[stat.id] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
		}, {
			Label = e(Text, {
				Size = UDim2.fromScale(0.55, 1),
				Text = stat.label,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Value = e(Text, {
				Position = UDim2.fromScale(0.55, 0),
				Size = UDim2.fromScale(0.45, 1),
				Text = statText(stat, stats),
				TextSize = 12,
				TextColor3 = if stat.format == "cash" then Theme.colors.cash else Theme.colors.text,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Settings = e("ScrollingFrame", {
			Size = UDim2.new(1, -(STATS_WIDTH + 16), 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
		Stats = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, STATS_WIDTH, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 24),
				Text = "Your stats",
				TextSize = 18,
				display = true,
			}),
			Rows = e("Frame", {
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 1, -32),
				BackgroundTransparency = 1,
			}, statRows),
		}),
	})
end

return React.memo(SettingsPage)
