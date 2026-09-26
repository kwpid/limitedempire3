-- Crash: the multiplier climbs until it crashes. cash out before it does, or set an auto cash out. the server rolls
-- the crash point and times everything (CashRoundService), this page draws the climb and tells it when to cash out.
-- props: cash

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CashGames = require(Shared.Games.CashGames)
local Crash = require(Shared.Games.Crash)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local BetInput = require(script.Parent.BetInput)
local Parts = require(script.Parent.CashGameParts)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local HISTORY_HEIGHT = 56
local DOTS = 40
local AUTO_PRESETS = { 1.5, 2, 5, 10 }
local CLIMB = Color3.fromRGB(80, 170, 240)

local function multiplierText(m: number): string
	return string.format("%.2fx", m)
end

local function CrashPage(props)
	local bet, setBet = React.useState(1000)
	local auto, setAuto = React.useState(nil) -- number or nil (off)
	local autoText, setAutoText = React.useState("")
	local running, setRunning = React.useState(false)
	local pending, setPending = React.useState(false)
	local cashed, setCashed = React.useState(nil) -- { multiplier, payout } this round
	local crashedAt, setCrashedAt = React.useState(nil)
	local wager, setWager = React.useState(0)
	local history, setHistory = React.useState({})
	local elapsed, setElapsed = React.useBinding(0)
	local startedAt = React.useRef(0)
	local cashedRef = React.useRef(nil)
	cashedRef.current = cashed
	local wagerRef = React.useRef(0)
	wagerRef.current = wager

	-- the climb, while a round runs
	React.useEffect(function()
		if not running then
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function()
			setElapsed(os.clock() - startedAt.current)
		end)
		return function()
			connection:Disconnect()
		end
	end, { running })

	-- crashes and auto cash outs come from the server
	React.useEffect(function()
		local connection = Net.events.CashRoundUpdate.OnClientEvent:Connect(function(gameId, event)
			if gameId ~= "crash" or type(event) ~= "table" then
				return
			end
			if event.kind == "cashout" then
				setCashed({ multiplier = event.multiplier, payout = event.payout })
				Parts.announce(true, wagerRef.current, event.payout)
			elseif event.kind == "crash" then
				setRunning(false)
				setCrashedAt(event.crash)
				setElapsed(Crash.timeFor(event.crash))
				local won = cashedRef.current ~= nil
				if not won then
					Sfx.play("error")
				end
				setHistory(function(list)
					return Parts.pushHistory(list, { text = multiplierText(event.crash), won = event.crash >= 2 })
				end)
			end
		end)
		-- a round still running from before the page was reopened picks up where it is
		task.spawn(function()
			local result = Actions.cashRound("crash", "state")
			if result.ok and result.data then
				startedAt.current = os.clock() - result.data.elapsed
				setWager(result.data.bet)
				setRunning(true)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local function setAutoValue(value: number?)
		setAuto(value)
		setAutoText(if value then string.format("%.2f", value) else "")
	end

	local function start()
		if running or pending then
			return
		elseif not CashGames.validBet(bet) then
			Parts.fail(`Bet between {Format.cash(CashGames.MIN_BET)} and {Format.cash(CashGames.MAX_BET)}`)
			return
		elseif bet > props.cash then
			Parts.fail("Not enough cash")
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.cashRound("crash", "start", { bet = bet, auto = auto })
			setPending(false)
			if not result.ok then
				Parts.fail(result.err)
				return
			end
			Sfx.play("whoosh")
			startedAt.current = os.clock()
			setElapsed(0)
			setWager(bet)
			setCashed(nil)
			setCrashedAt(nil)
			setRunning(true)
		end)
	end

	local function cashOut()
		if not running or cashed or pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.cashRound("crash", "cashout")
			setPending(false)
			if result.ok then
				setCashed(result.data)
				Parts.announce(true, wager, result.data.payout)
			else
				Parts.fail(result.err)
			end
		end)
	end

	local autoPills = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Off = e(Button, {
			layoutOrder = 0,
			size = UDim2.new(1 / (#AUTO_PRESETS + 1), -5, 1, 0),
			text = "Off",
			textSize = 13,
			color = if auto == nil then Theme.colors.accent else Theme.colors.panelLight,
			disabled = running,
			onClick = function()
				setAutoValue(nil)
			end,
		}),
	}
	for index, value in AUTO_PRESETS do
		autoPills["Preset" .. index] = e(Button, {
			layoutOrder = index,
			size = UDim2.new(1 / (#AUTO_PRESETS + 1), -5, 1, 0),
			text = `{value}x`,
			textSize = 13,
			color = if auto == value then Theme.colors.accent else Theme.colors.panelLight,
			disabled = running,
			onClick = function()
				setAutoValue(value)
			end,
		})
	end

	-- the big number and its color
	local liveMultiplier = elapsed:map(function(t)
		if crashedAt then
			return multiplierText(crashedAt)
		end
		return multiplierText(Crash.multiplierAt(t))
	end)
	local numberColor = if crashedAt and not cashed then Parts.LOSE elseif cashed then Parts.WIN else Theme.colors.text

	local status = "Set a bet and start"
	if running and cashed then
		status = `Cashed out at {multiplierText(cashed.multiplier)}: +{Format.cash(cashed.payout)}`
	elseif running then
		status = if auto then `Auto cash out at {multiplierText(auto)}` else "Cash out before it crashes!"
	elseif crashedAt and cashed then
		status = `Crashed at {multiplierText(crashedAt)}. You cashed out at {multiplierText(cashed.multiplier)}`
	elseif crashedAt then
		status = `Crashed at {multiplierText(crashedAt)}. You lost {Format.cash(wager)}`
	end

	-- the curve, as dots along it, scaled so the whole climb stays in view
	local dots = {}
	for i = 1, DOTS do
		dots["Dot" .. i] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = elapsed:map(function(t)
				local xMax = math.max(8, t)
				local yMax = math.max(2, math.exp(Crash.GROWTH * t) * 1.15)
				local ti = t * i / DOTS
				local m = math.exp(Crash.GROWTH * ti)
				return UDim2.fromScale(ti / xMax, 1 - (m - 1) / (yMax - 1))
			end),
			Size = UDim2.fromOffset(if i == DOTS then 12 else 6, if i == DOTS then 12 else 6),
			BackgroundColor3 = if crashedAt and not cashed then Parts.LOSE elseif cashed then Parts.WIN else CLIMB,
			BorderSizePixel = 0,
			Visible = elapsed:map(function(t)
				return t > 0.05
			end),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end

	local potential = elapsed:map(function(t)
		return Format.cash(CashGames.payout(wager, Crash.multiplierAt(t)))
	end)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Panel = e(Parts.Panel, nil, {
			Bet = e(BetInput, {
				value = bet,
				onChange = setBet,
				cash = props.cash,
				disabled = running,
			}),
			AutoLabel = e(Text, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Auto cash out",
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				display = true,
			}),
			Auto = e("Frame", {
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
					TextEditable = not running,
					Text = autoText,
					PlaceholderText = "Off",
					PlaceholderColor3 = Theme.colors.textFaint,
					TextColor3 = Theme.colors.text,
					FontFace = Theme.font(Enum.FontWeight.Bold),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					[React.Change.Text] = function(box: TextBox)
						setAutoText(box.Text)
					end,
					[React.Event.FocusLost] = function(box: TextBox)
						local value = tonumber(box.Text)
						if value and Crash.validAuto(value) then
							setAutoValue(math.floor(value * 100) / 100)
						else
							setAutoValue(nil)
						end
					end,
				}),
				Suffix = e(Text, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 0),
					Size = UDim2.new(0, 20, 1, 0),
					Text = "x",
					TextSize = 16,
					TextColor3 = Theme.colors.textDim,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),
			Presets = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
			}, autoPills),
			Payout = e(Parts.Line, {
				layoutOrder = 5,
				label = if running and not cashed then "Cash out now" else "Win at 2x",
				value = if running and not cashed then potential else Format.cash(CashGames.payout(bet, 2)),
				color = Theme.colors.cash,
			}),
			Action = if running
				then e(Button, {
					layoutOrder = 6,
					size = UDim2.new(1, 0, 0, 48),
					text = if cashed then "Cashed out" else "Cash out",
					textSize = 19,
					color = Theme.colors.cash:Lerp(Theme.colors.panel, 0.3),
					disabled = cashed ~= nil or pending,
					sound = false,
					onClick = cashOut,
				})
				else e(Button, {
					layoutOrder = 6,
					size = UDim2.new(1, 0, 0, 48),
					text = if pending then "Starting..." else `Start  ·  {Format.cash(bet)}`,
					textSize = 19,
					color = Theme.colors.good,
					disabled = pending or bet > props.cash or not CashGames.validBet(bet),
					sound = false,
					onClick = start,
				}),
			Note = e(Text, {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 16),
				Text = `{math.floor(CashGames.HOUSE_EDGE * 100)}% house edge · can crash at 1.00x`,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
		}),
		Stage = e("Frame", {
			Position = UDim2.fromOffset(Parts.PANEL_WIDTH + 14, 0),
			Size = UDim2.new(1, -(Parts.PANEL_WIDTH + 14), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Graph = e("Frame", {
				Size = UDim2.new(1, 0, 1, -(HISTORY_HEIGHT + 44)),
				BackgroundColor3 = Theme.colors.inset,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Plot = e("Frame", {
					Position = UDim2.fromOffset(24, 24),
					Size = UDim2.new(1, -48, 1, -48),
					BackgroundTransparency = 1,
				}, dots),
				Multiplier = e(Text, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.new(1, 0, 0, 90),
					Text = liveMultiplier,
					TextSize = 84,
					TextColor3 = numberColor,
					TextXAlignment = Enum.TextXAlignment.Center,
					display = true,
					weight = Enum.FontWeight.Bold,
					ZIndex = 2,
				}),
			}),
			Status = e(Text, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -(HISTORY_HEIGHT + 8)),
				Size = UDim2.new(1, 0, 0, 28),
				Text = status,
				TextSize = 20,
				TextColor3 = if cashed then Parts.WIN elseif crashedAt then Parts.LOSE else Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
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

return CrashPage
