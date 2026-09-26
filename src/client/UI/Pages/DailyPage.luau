-- the daily rewards window: the streak, a claim button, and the 14 day calendar with each day's cash and Season Points
-- (Shared/Progress/DailyLogin). days already claimed this cycle are ticked off, today's is highlighted.
-- props: view (Daily controller view, or nil while loading)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local DailyLogin = require(Shared.Progress.DailyLogin)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Checkmark = require(script.Parent.Parent.Components.Checkmark)
local Daily = require(script.Parent.Parent.Parent.Controllers.Daily)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local HEADER_HEIGHT = 96
local GAP = 8
-- the calendar is placed by hand (7 columns, 2 rows) instead of a UIGridLayout: a grid that fills the width
-- exactly can round a cell onto a third row, pushing the last days out of view
local COLUMNS = 7
local ROWS = 2
local SP_COLOR = Color3.fromRGB(180, 110, 255)
local BIG_COLOR = Color3.fromRGB(245, 185, 28)

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m {seconds % 60}s`
end

local function DayCard(props)
	local reward = props.reward
	local state = props.state -- "claimed" | "today" | "next" | "future"
	local accent = if reward.big then BIG_COLOR elseif state == "today" then Theme.colors.good else Theme.colors.stroke
	local claimed = state == "claimed"

	local column = (props.day - 1) % COLUMNS
	local row = (props.day - 1) // COLUMNS
	return e("Frame", {
		Position = UDim2.new(column / COLUMNS, column * GAP / COLUMNS, row / ROWS, row * GAP / ROWS),
		Size = UDim2.new(1 / COLUMNS, -GAP * (COLUMNS - 1) / COLUMNS, 1 / ROWS, -GAP * (ROWS - 1) / ROWS),
		BackgroundColor3 = if state == "today" then Theme.colors.panelLight else Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Color = accent,
			Thickness = if state == "today" or reward.big then 2 else 1,
			Transparency = if claimed then 0.6 else 0,
		}),
		Glow = reward.big and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BIG_COLOR,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(1, 0.75),
			}),
		}) or nil,
		Day = e(Text, {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 18),
			Text = `Day {props.day}`,
			TextSize = 16,
			TextColor3 = if reward.big then BIG_COLOR else Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
		}),
		Cash = e(Text, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 2),
			Size = UDim2.new(1, -8, 0, 24),
			Text = Format.cash(reward.cash),
			TextSize = if reward.big then 22 else 19,
			TextColor3 = Theme.colors.cash,
			TextTransparency = if claimed then 0.5 else 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Sp = e(Text, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -10),
			Size = UDim2.new(1, -8, 0, 16),
			Text = `+{reward.sp} SP`,
			TextSize = 14,
			TextColor3 = SP_COLOR,
			TextTransparency = if claimed then 0.5 else 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			weight = Enum.FontWeight.Bold,
		}),
		Tick = claimed and e(Checkmark, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -6, 0, 6),
			size = 18,
			zIndex = 3,
		}) or nil,
		Today = (state == "today" or state == "next") and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(70, 18),
			BackgroundColor3 = if state == "today" then Theme.colors.good else Theme.colors.panelLight,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Label = e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = if state == "today" then "Today" else "Tomorrow",
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				ZIndex = 4,
			}),
		}) or nil,
	})
end

local function DailyPage(props)
	local view = props.view
	local pending, setPending = React.useState(false)
	local now, setNow = React.useState(os.clock())

	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					setNow(os.clock())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})

	if not view then
		return e(Text, {
			Size = UDim2.fromScale(1, 1),
			Text = "Loading...",
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	local function claim()
		if pending or not view.claimable then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Daily.claim()
			setPending(false)
			if result.ok then
				local reward = result.data.reward
				Sfx.play("unlock")
				Notifications.push(
					`Day {reward.day} claimed: +{Format.cash(reward.cash)}, +{reward.sp} SP`,
					Color3.fromRGB(130, 210, 120)
				)
			else
				Sfx.play("error")
				Notifications.push(result.err or "Could not claim", Theme.colors.bad)
			end
		end)
	end

	local resetsIn = view.resetsIn - (now - (view.fetchedAt or now))
	local claimedThrough = if view.claimedToday then view.day else view.day - 1
	local cards = {}
	for day, reward in DailyLogin.REWARDS do
		local state = "future"
		if day <= claimedThrough then
			state = "claimed"
		elseif day == view.day then
			state = "today"
		end
		if view.claimedToday and day == DailyLogin.dayFor(view.streak + 1) and day ~= view.day then
			state = "next"
		end
		cards["Day" .. day] = e(DayCard, { day = day, reward = reward, state = state })
	end

	local status = if view.claimable
		then `Your Day {view.day} reward is ready!`
		else `Come back in {countdown(resetsIn)} for Day {DailyLogin.dayFor(view.streak + 1)}`

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT - 12),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Streak = e(Text, {
				Position = UDim2.fromOffset(20, 10),
				Size = UDim2.new(0, 200, 0, 44),
				Text = `{view.streak}`,
				TextSize = 44,
				TextColor3 = if view.streak > 0 then Theme.colors.marker else Theme.colors.textFaint,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			StreakLabel = e(Text, {
				Position = UDim2.fromOffset(20, 56),
				Size = UDim2.new(0, 200, 0, 16),
				Text = "Day streak",
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				display = true,
			}),
			Status = e(Text, {
				Position = UDim2.fromOffset(150, 16),
				Size = UDim2.new(1, -(150 + 250), 0, 26),
				Text = status,
				TextSize = 21,
				TextColor3 = if view.claimable then Color3.fromRGB(130, 210, 120) else Theme.colors.text,
				display = true,
			}),
			Rule = e(Text, {
				Position = UDim2.fromOffset(150, 48),
				Size = UDim2.new(1, -(150 + 250), 0, 16),
				Text = "Claim once a day to keep your streak. Miss a day and it starts over at Day 1.",
				TextSize = 13,
				TextColor3 = Theme.colors.textFaint,
			}),
			Claim = e(Button, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -18, 0.5, 0),
				size = UDim2.fromOffset(220, 50),
				text = if pending then "Claiming..." elseif view.claimable then "Claim" else "Claimed",
				textSize = 22,
				color = Theme.colors.good,
				disabled = pending or not view.claimable,
				sound = false,
				onClick = claim,
			}),
		}),
		Calendar = e("Frame", {
			Position = UDim2.fromOffset(0, HEADER_HEIGHT),
			Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
			BackgroundTransparency = 1,
		}, {
			Padding = e("UIPadding", { PaddingTop = UDim.new(0, 10) }),
			Grid = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, cards),
		}),
	})
end

return DailyPage
