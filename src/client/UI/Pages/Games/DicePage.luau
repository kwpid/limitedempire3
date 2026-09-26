-- Dice: pick your win chance, then roll 0 to 100. rolling under your chance wins, and a lower chance pays more
-- (CashGames.diceMultiplier). the server rolls (GameService:CashGame), the number spins here and lands on it.
-- props: cash

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CashGames = require(Shared.Games.CashGames)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local BetInput = require(script.Parent.BetInput)
local Parts = require(script.Parent.CashGameParts)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local ROLL_TIME = 0.8
local HISTORY_HEIGHT = 56
local BAR_HEIGHT = 18
local PRESETS = { 10, 25, 50, 75, 90 }

local function DicePage(props)
	local bet, setBet = React.useState(1000)
	local chance, setChance = React.useState(50)
	local chanceText, setChanceText = React.useState("50")
	local rolling, setRolling = React.useState(false)
	local outcome, setOutcome = React.useState(nil)
	local history, setHistory = React.useState({})
	local shown, setShown = React.useBinding(50)
	local alive = React.useRef(true)

	React.useEffect(function()
		alive.current = true
		return function()
			alive.current = false
		end
	end, {})

	local multiplier = CashGames.diceMultiplier(chance)

	local function pickChance(value: number)
		local clamped = math.clamp(math.floor(value), CashGames.MIN_CHANCE, CashGames.MAX_CHANCE)
		setChance(clamped)
		setChanceText(tostring(clamped))
	end

	local function roll()
		if rolling then
			return
		elseif not CashGames.validBet(bet) then
			Parts.fail(`Bet between {Format.cash(CashGames.MIN_BET)} and {Format.cash(CashGames.MAX_BET)}`)
			return
		elseif bet > props.cash then
			Parts.fail("Not enough cash")
			return
		end
		local wager, target = bet, chance
		setRolling(true)
		setOutcome(nil)
		Sfx.play("tick")
		task.spawn(function()
			local result = Actions.cashGame("dice", wager, target)
			if not alive.current then
				return
			end
			if not result.ok then
				setRolling(false)
				Parts.fail(result.err)
				return
			end
			local data = result.data
			-- the number flickers, then eases onto the roll
			local from = shown:getValue()
			local started = os.clock()
			local lastTick = 0
			while alive.current do
				local p = math.clamp((os.clock() - started) / ROLL_TIME, 0, 1)
				local eased = 1 - (1 - p) ^ 3
				local jitter = (1 - p) * (math.random() - 0.5) * 40
				setShown(math.clamp(from + (data.result - from) * eased + jitter, 0, 100))
				if os.clock() - lastTick > 0.08 and p < 0.8 then
					lastTick = os.clock()
					Sfx.play("tick")
				end
				if p >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if not alive.current then
				return
			end
			setShown(data.result)
			setOutcome({ won = data.won, payout = data.payout, bet = wager, roll = data.result, chance = target })
			setHistory(function(list)
				return Parts.pushHistory(list, { text = string.format("%.2f", data.result), won = data.won })
			end)
			Parts.announce(data.won, wager, data.payout)
			setRolling(false)
		end)
	end

	local presets = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, value in PRESETS do
		presets["Preset" .. value] = e(Button, {
			layoutOrder = index,
			size = UDim2.new(1 / #PRESETS, -5, 1, 0),
			text = `{value}%`,
			textSize = 14,
			color = if chance == value then Theme.colors.accent else Theme.colors.panelLight,
			disabled = rolling,
			onClick = function()
				pickChance(value)
			end,
		})
	end

	local resultText, resultColor = "Roll under your chance to win", Theme.colors.textDim
	if rolling then
		resultText = "Rolling..."
	elseif outcome then
		resultText = if outcome.won
			then `Under {outcome.chance}! You won {Format.cash(outcome.payout)}`
			else `Over {outcome.chance}. You lost {Format.cash(outcome.bet)}`
		resultColor = if outcome.won then Parts.WIN else Parts.LOSE
	end
	local numberColor = if outcome and not rolling
		then (if outcome.won then Parts.WIN else Parts.LOSE)
		else Theme.colors.text

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Panel = e(Parts.Panel, nil, {
			Bet = e(BetInput, {
				value = bet,
				onChange = setBet,
				cash = props.cash,
				disabled = rolling,
			}),
			ChanceLabel = e(Text, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Win chance",
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				display = true,
			}),
			Chance = e("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Input = e("TextBox", {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -44, 1, 0),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					TextEditable = not rolling,
					Text = chanceText,
					TextColor3 = Theme.colors.text,
					FontFace = Theme.font(Enum.FontWeight.Bold),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					[React.Change.Text] = function(box: TextBox)
						setChanceText(box.Text)
						local value = tonumber(box.Text)
						if value and CashGames.validChance(value) then
							setChance(value)
						end
					end,
					[React.Event.FocusLost] = function(box: TextBox)
						pickChance(tonumber(box.Text) or chance)
					end,
				}),
				Percent = e(Text, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 0),
					Size = UDim2.new(0, 20, 1, 0),
					Text = "%",
					TextSize = 16,
					TextColor3 = Theme.colors.textDim,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),
			Presets = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, presets),
			Multiplier = e(Parts.Line, {
				layoutOrder = 5,
				label = "Multiplier",
				value = string.format("%.2fx", multiplier),
			}),
			Win = e(Parts.Line, {
				layoutOrder = 6,
				label = "Win",
				value = Format.cash(CashGames.payout(bet, multiplier)),
				color = Theme.colors.cash,
			}),
			Roll = e(Button, {
				layoutOrder = 7,
				size = UDim2.new(1, 0, 0, 48),
				text = if rolling then "Rolling..." else `Roll  ·  {Format.cash(bet)}`,
				textSize = 19,
				color = Theme.colors.good,
				disabled = rolling or bet > props.cash or not CashGames.validBet(bet),
				sound = false,
				onClick = roll,
			}),
			Note = e(Text, {
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 16),
				Text = `{CashGames.MIN_CHANCE}% to {CashGames.MAX_CHANCE}% · {math.floor(CashGames.HOUSE_EDGE * 100)}% house edge`,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
		}),
		Stage = e("Frame", {
			Position = UDim2.fromOffset(Parts.PANEL_WIDTH + 14, 0),
			Size = UDim2.new(1, -(Parts.PANEL_WIDTH + 14), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Number = e(Text, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -(HISTORY_HEIGHT / 2 + 70)),
				Size = UDim2.new(1, 0, 0, 90),
				Text = shown:map(function(value)
					return string.format("%.2f", value)
				end),
				TextSize = 84,
				TextColor3 = numberColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Result = e(Text, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -(HISTORY_HEIGHT / 2 - 4)),
				Size = UDim2.new(1, 0, 0, 30),
				Text = resultText,
				TextSize = 22,
				TextColor3 = resultColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
			}),
			-- 0 to 100: the green part wins, the marker is the roll
			Bar = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, -(HISTORY_HEIGHT / 2) + 34),
				Size = UDim2.new(1, -40, 0, BAR_HEIGHT),
				BackgroundColor3 = Parts.LOSE:Lerp(Theme.colors.panel, 0.55),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Win = e("Frame", {
					Size = UDim2.fromScale(chance / 100, 1),
					BackgroundColor3 = Parts.WIN:Lerp(Theme.colors.panel, 0.3),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				Marker = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = shown:map(function(value)
						return UDim2.fromScale(value / 100, 0.5)
					end),
					Size = UDim2.fromOffset(6, BAR_HEIGHT + 16),
					BackgroundColor3 = Theme.colors.text,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				Zero = e(Text, {
					Position = UDim2.fromOffset(0, BAR_HEIGHT + 6),
					Size = UDim2.fromOffset(40, 16),
					Text = "0",
					TextSize = 12,
					TextColor3 = Theme.colors.textFaint,
				}),
				Hundred = e(Text, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, BAR_HEIGHT + 6),
					Size = UDim2.fromOffset(40, 16),
					Text = "100",
					TextSize = 12,
					TextColor3 = Theme.colors.textFaint,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),
			History = e(Parts.History, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				size = UDim2.new(1, 0, 0, HISTORY_HEIGHT),
				entries = history,
			}),
		}),
	})
end

return DicePage
