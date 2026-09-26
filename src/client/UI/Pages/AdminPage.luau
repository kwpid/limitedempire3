local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local usePlayerAttribute = require(script.Parent.Parent.Hooks.usePlayerAttribute)

local e = React.createElement

local QUICK_AMOUNTS = { 1_000, 10_000, 100_000, 1_000_000, 100_000_000 }
local QUICK_LUCK = { 1, 2, 5, 10, 50, 100, 1000 }
local CONFIRM_WINDOW = 3

local function parseAmount(text: string): number?
	local cleaned = text:gsub("[,%s]", ""):lower()
	local number, suffix = cleaned:match("^(-?[%d%.]+)([kmb]?)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9 })[suffix] or 1
	return value * mult
end

local function formatLuck(luck: number?): string
	local value = if type(luck) == "number" then luck else 1
	if value == math.floor(value) then
		return `{Format.commas(value)}x`
	end
	return string.format("%.2fx", value)
end

local function Section(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = props.title,
			TextSize = 18,
			display = true,
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, children)
end

local function AdminPage(props)
	local inputRef = React.useRef(nil)
	local luckInputRef = React.useRef(nil)
	local pending, setPending = React.useState(false)
	local armed, setArmed = React.useState(nil)
	local luck = usePlayerAttribute("Luck") or 1
	local nameStyle = usePlayerAttribute("NameStyle")

	local function run(action: string, amount: number?)
		if pending then
			return
		end
		if not amount then
			Notifications.push("Enter a number, like 5000 or 2.5m", Theme.colors.bad)
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin(action, { amount = amount })
			setPending(false)
			if result.ok then
				local shown = if action == "setLuck" then formatLuck(amount) else Format.commas(amount)
				Notifications.push(`[admin] {action} {shown}`, Theme.colors.cash)
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local function readInput(): number?
		local box = inputRef.current
		return box and parseAmount(box.Text)
	end

	local function confirmThen(action: string, message: string)
		if pending then
			return
		end
		if armed ~= action then
			setArmed(action)
			task.delay(CONFIRM_WINDOW, function()
				setArmed(function(current)
					return if current == action then nil else current
				end)
			end)
			return
		end
		setArmed(nil)
		setPending(true)
		task.spawn(function()
			local result = Actions.admin(action, nil)
			setPending(false)
			if result.ok then
				Notifications.push(message, Theme.colors.cash)
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local styleButtons = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, style in NameStyles.list do
		styleButtons[style.id] = e(Button, {
			layoutOrder = index,
			text = style.name,
			textSize = 15,
			color = if nameStyle == style.id then Theme.colors.accent else nil,
			disabled = pending,
			onClick = function()
				setPending(true)
				task.spawn(function()
					local result = Actions.admin("setNameStyle", { style = style.id })
					setPending(false)
					if not result.ok then
						Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
					end
				end)
			end,
		})
	end

	local luckButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, amount in QUICK_LUCK do
		luckButtons["Luck" .. amount] = e(Button, {
			layoutOrder = index,
			size = UDim2.fromOffset(72, 34),
			text = formatLuck(amount),
			textSize = 15,
			color = if luck == amount then Theme.colors.accent else nil,
			disabled = pending,
			onClick = function()
				run("setLuck", amount)
			end,
		})
	end

	local quickButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, amount in QUICK_AMOUNTS do
		quickButtons["Add" .. amount] = e(Button, {
			layoutOrder = index,
			size = UDim2.fromOffset(92, 34),
			text = "+" .. Format.short(amount),
			textSize = 15,
			disabled = pending,
			onClick = function()
				run("addCash", amount)
			end,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Cash = e(Section, {
			title = "Cash",
			size = UDim2.new(0, 560, 0, 190),
		}, {
			Balance = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Current balance: {Config.Currency.Symbol}{Format.commas(props.cash)}`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Quick = e("Frame", {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, quickButtons),
			Input = e("TextBox", {
				ref = inputRef,
				Position = UDim2.fromOffset(0, 104),
				Size = UDim2.fromOffset(200, 36),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Amount (5000, 2.5m, 1b)",
				PlaceholderColor3 = Theme.colors.textFaint,
				Text = "",
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Medium),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
			}),
			Add = e(Button, {
				position = UDim2.fromOffset(210, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Add",
				color = Theme.colors.good,
				disabled = pending,
				onClick = function()
					run("addCash", readInput())
				end,
			}),
			Set = e(Button, {
				position = UDim2.fromOffset(312, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Set",
				color = Theme.colors.accent,
				disabled = pending,
				onClick = function()
					run("setCash", readInput())
				end,
			}),
			Reset = e(Button, {
				position = UDim2.fromOffset(414, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Zero",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					run("setCash", 0)
				end,
			}),
		}),
		Luck = e(Section, {
			title = "Luck",
			position = UDim2.fromOffset(0, 202),
			size = UDim2.new(0, 560, 0, 190),
		}, {
			Current = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Current luck: {formatLuck(luck)}. Boosts expensive drops and trait chances.`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Quick = e("Frame", {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, luckButtons),
			Input = e("TextBox", {
				ref = luckInputRef,
				Position = UDim2.fromOffset(0, 104),
				Size = UDim2.fromOffset(200, 36),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Luck (2, 7.5, 250)",
				PlaceholderColor3 = Theme.colors.textFaint,
				Text = "",
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Medium),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
			}),
			Set = e(Button, {
				position = UDim2.fromOffset(210, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Set",
				color = Theme.colors.accent,
				disabled = pending,
				onClick = function()
					local box = luckInputRef.current
					run("setLuck", box and parseAmount(box.Text))
				end,
			}),
			Reset = e(Button, {
				position = UDim2.fromOffset(312, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Reset",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					run("setLuck", 1)
				end,
			}),
		}),
		NameStyle = e(Section, {
			title = "Name style",
			position = UDim2.fromOffset(576, 202),
			size = UDim2.new(1, -576, 0, 190),
		}, {
			Current = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Overhead name style: {NameStyles.get(nameStyle).name}`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Styles = e("Frame", {
				Position = UDim2.fromOffset(0, 54),
				Size = UDim2.new(1, 0, 1, -54),
				BackgroundTransparency = 1,
			}, styleButtons),
		}),
		Data = e(Section, {
			title = "Data",
			position = UDim2.fromOffset(576, 0),
			size = UDim2.new(1, -576, 0, 190),
		}, {
			Info = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 36),
				Text = "Wipes save your changes right away. Click twice to confirm.",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Wipe = e(Button, {
				position = UDim2.fromOffset(0, 70),
				size = UDim2.new(1, 0, 0, 36),
				text = if armed == "wipeData" then "Click again to confirm" else "Wipe my data",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					confirmThen("wipeData", "[admin] your data was wiped")
				end,
			}),
			WipeAll = e(Button, {
				position = UDim2.fromOffset(0, 114),
				size = UDim2.new(1, 0, 0, 36),
				text = if armed == "wipeAll" then "Click again to confirm" else "Wipe data + reset serials",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					confirmThen("wipeAll", "[admin] data wiped and serials reset")
				end,
			}),
		}),
	})
end

return React.memo(AdminPage)
