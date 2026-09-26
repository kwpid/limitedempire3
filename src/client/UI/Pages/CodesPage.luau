-- the Codes tab in settings: type a code to redeem it (CodeService), and see active boosts with their timers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local SearchBox = require(script.Parent.Parent.Components.SearchBox)
local useBoosts = require(script.Parent.Parent.Hooks.useBoosts)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local GOOD = Color3.fromRGB(130, 210, 120)
local BAD = Color3.fromRGB(220, 110, 90)

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

local function Panel(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, children)
end

local function CodesPage()
	local code, setCode = React.useState("")
	local pending, setPending = React.useState(false)
	local result, setResult = React.useState(nil)
	local boosts = useBoosts()

	local function redeem()
		if pending or code == "" then
			return
		end
		setPending(true)
		task.spawn(function()
			local response = Actions.redeemCode(code)
			setPending(false)
			if response.ok then
				Sfx.play("unlock")
				local text = table.concat(response.data.rewards, ",  ")
				setResult({ ok = true, text = `Redeemed {string.upper(code)}: {text}` })
				Notifications.push(`Code redeemed: {text}`, GOOD)
				setCode("")
			else
				Sfx.play("error")
				setResult({ ok = false, text = response.err or "Could not redeem that code" })
			end
		end)
	end

	local boostRows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, boost in boosts do
		boostRows[boost.kind] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = boost.color, Transparency = 0.5 }),
			Strip = e("Frame", {
				Size = UDim2.new(0, 3, 1, 0),
				BackgroundColor3 = boost.color,
				BorderSizePixel = 0,
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(0.6, -16, 1, 0),
				Text = `{boost.multiplier}x {boost.name} boost`,
				TextSize = 17,
				TextColor3 = boost.color,
				display = true,
			}),
			Time = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				Text = `{clock(boost.remaining)} left`,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Redeem = e(Panel, {
			size = UDim2.new(0.5, -8, 1, 0),
		}, {
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 28),
				Text = "Redeem a code",
				TextSize = 24,
				display = true,
			}),
			Hint = e(Text, {
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 0, 36),
				Text = "Codes give cash or timed boosts. Watch updates and the group for new ones.",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Input = e(SearchBox, {
				position = UDim2.fromOffset(0, 80),
				size = UDim2.new(1, 0, 0, 44),
				value = code,
				placeholder = "Enter code",
				onChange = function(text)
					setCode(text)
					setResult(nil)
				end,
			}),
			Button = e(Button, {
				position = UDim2.fromOffset(0, 134),
				size = UDim2.new(1, 0, 0, 46),
				text = if pending then "Redeeming..." else "Redeem",
				textSize = 18,
				color = Theme.colors.good,
				disabled = pending or code == "",
				sound = false,
				onClick = redeem,
			}),
			Result = result and e(Text, {
				Position = UDim2.fromOffset(0, 192),
				Size = UDim2.new(1, 0, 0, 40),
				Text = result.text,
				TextSize = 14,
				TextColor3 = if result.ok then GOOD else BAD,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}) or nil,
		}),
		Boosts = e(Panel, {
			position = UDim2.new(0.5, 8, 0, 0),
			size = UDim2.new(0.5, -8, 1, 0),
		}, {
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 28),
				Text = "Active boosts",
				TextSize = 24,
				display = true,
			}),
			Hint = e(Text, {
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 0, 36),
				Text = "Cash boosts multiply passive income, quest and login rewards. XP and SP boosts multiply everything you earn.",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			List = e("Frame", {
				Position = UDim2.fromOffset(0, 80),
				Size = UDim2.new(1, 0, 1, -80),
				BackgroundTransparency = 1,
			}, boostRows),
			None = #boosts == 0 and e(Text, {
				Position = UDim2.fromOffset(0, 80),
				Size = UDim2.new(1, 0, 0, 20),
				Text = "No active boosts",
				TextSize = 14,
				TextColor3 = Theme.colors.textFaint,
			}) or nil,
		}),
	})
end

return CodesPage
