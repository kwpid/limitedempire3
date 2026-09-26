-- Higher or Lower: two items, the right one's value is hidden. guess if it is worth more or less than the left one.
-- every correct guess in a row pays a bit more (see Shared/Games/HigherLower), up to a daily limit; a wrong guess
-- ends the run. the server picks the items and checks the guesses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local HigherLower = require(Shared.Games.HigherLower)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local REVEAL_TIME = 0.6
local NEXT_DELAY = 1.1

local function Card(props)
	local info = ItemRegistry.get(props.assetId)
	local tier = ItemRegistry.tier(props.assetId)
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.new(0.5, -40, 1, -120),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", { Color = props.strokeColor or Theme.colors.stroke, Thickness = 2 }),
		Fade = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = tier.color,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 0.7),
				}),
			}),
		}),
		Thumb = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.new(0.62, 0, 0.62, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(props.assetId, 420),
			ScaleType = Enum.ScaleType.Fit,
		}),
		Name = e(Text, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -52),
			Size = UDim2.new(1, -24, 0, 22),
			Text = info and info.name or "Unknown",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -14),
			Size = UDim2.new(1, -24, 0, 34),
			Text = props.valueText,
			TextSize = 32,
			TextColor3 = props.valueColor or Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
	})
end

local function HigherLowerPage()
	local round, setRound = React.useState(nil)
	local reveal, setReveal = React.useState(nil)
	local over, setOver = React.useState(nil)
	local pending, setPending = React.useState(false)
	local shownValue, setShownValue = React.useBinding(0)

	local function start()
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.hiloStart()
			setPending(false)
			if result.ok then
				setOver(nil)
				setReveal(nil)
				setRound(result.data)
			else
				Notifications.push(result.err or "Could not start", Theme.colors.bad)
			end
		end)
	end

	-- counts the hidden value up when it is revealed
	React.useEffect(function()
		if not reveal then
			return nil
		end
		local startAt = os.clock()
		local connection = RunService.RenderStepped:Connect(function()
			local p = math.clamp((os.clock() - startAt) / REVEAL_TIME, 0, 1)
			setShownValue(math.floor(reveal.value * (1 - (1 - p) ^ 3)))
		end)
		return function()
			connection:Disconnect()
		end
	end, { reveal } :: { any })

	local function guess(choice: string)
		if pending or reveal or not round then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.hiloGuess(choice)
			if not result.ok then
				setPending(false)
				Notifications.push(result.err or "Guess failed", Theme.colors.bad)
				return
			end
			local data = result.data
			setReveal({ value = data.rightValue, correct = data.correct })
			if data.correct then
				Sfx.play("revealRare", 1.1)
				if data.reward and data.reward > 0 then
					Notifications.push(`+{Format.cash(data.reward)}  ·  streak {data.streak}`, Theme.colors.cash)
				end
			else
				Sfx.play("error")
			end
			task.wait(NEXT_DELAY)
			setPending(false)
			setReveal(nil)
			if data.correct then
				setRound(data.next)
			else
				setOver({ streak = data.streak })
			end
		end)
	end

	local header = {}
	if round then
		local earned = round.earnedToday or 0
		header = {
			Streak = e(Text, {
				Size = UDim2.new(0.5, 0, 0, 26),
				Text = `Streak {round.streak}`,
				TextSize = 22,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Daily = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, 0, 0, 16),
				Text = `Earned today {Format.cash(earned)} / {Format.cash(HigherLower.DAILY_CAP)}`,
				TextSize = 12,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Next = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 18),
				Size = UDim2.new(0.5, 0, 0, 16),
				Text = if earned >= HigherLower.DAILY_CAP
					then "Daily limit reached, play for fun"
					else `Next correct guess pays {Format.cash(HigherLower.reward(round.streak + 1))}`,
				TextSize = 12,
				TextColor3 = Theme.colors.cash,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end

	if not round then
		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Title = e(Text, {
				Position = UDim2.fromScale(0, 0.3),
				Size = UDim2.new(1, 0, 0, 40),
				Text = "Higher or Lower",
				TextSize = 36,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Rules = e(Text, {
				Position = UDim2.new(0, 0, 0.3, 46),
				Size = UDim2.new(1, 0, 0, 40),
				Text = `Guess if the next item is worth more or less. Each correct guess in a row pays more, up to {Format.cash(
					HigherLower.DAILY_CAP
				)} a day.`,
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
			}),
			Play = e(Button, {
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0.3, 100),
				size = UDim2.fromOffset(220, 46),
				text = "Play",
				textSize = 20,
				color = Theme.colors.good,
				disabled = pending,
				onClick = start,
			}),
		})
	end

	local rightText = "?"
	local rightColor = Theme.colors.textDim
	local rightStroke = nil
	if reveal then
		rightText = shownValue:map(function(value)
			return Format.cash(value)
		end)
		rightColor = if reveal.correct then Theme.colors.good else Theme.colors.bad
		rightStroke = rightColor
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
		}, header),
		Left = e(Card, {
			position = UDim2.fromOffset(0, 44),
			assetId = round.left.assetId,
			valueText = Format.cash(round.left.value),
		}),
		Versus = e(Text, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -20),
			Size = UDim2.fromOffset(60, 30),
			Text = "VS",
			TextSize = 26,
			TextColor3 = Theme.colors.textFaint,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Right = e(Card, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, 44),
			assetId = round.right.assetId,
			valueText = rightText,
			valueColor = rightColor,
			strokeColor = rightStroke,
		}),
		Buttons = e(
			"Frame",
			{
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundTransparency = 1,
			},
			if over
				then {
					Over = e(Text, {
						Size = UDim2.new(0.5, -10, 1, 0),
						Text = `Wrong! Your streak ended at {over.streak}`,
						TextSize = 18,
						TextColor3 = Theme.colors.bad,
						display = true,
					}),
					Again = e(Button, {
						anchorPoint = Vector2.new(1, 0),
						position = UDim2.fromScale(1, 0),
						size = UDim2.new(0.5, -10, 1, 0),
						text = "Play again",
						textSize = 20,
						color = Theme.colors.good,
						disabled = pending,
						onClick = start,
					}),
				}
				else {
					Lower = e(Button, {
						size = UDim2.new(0.5, -6, 1, 0),
						text = "Lower",
						textSize = 22,
						color = Theme.colors.bad,
						disabled = pending or reveal ~= nil,
						onClick = function()
							guess("lower")
						end,
					}),
					Higher = e(Button, {
						anchorPoint = Vector2.new(1, 0),
						position = UDim2.fromScale(1, 0),
						size = UDim2.new(0.5, -6, 1, 0),
						text = "Higher",
						textSize = 22,
						color = Theme.colors.good,
						disabled = pending or reveal ~= nil,
						onClick = function()
							guess("higher")
						end,
					}),
				}
		),
	})
end

return HigherLowerPage
