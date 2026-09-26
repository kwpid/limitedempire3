-- Coinflip: bet cash on heads or tails. the server flips (GameService:CashGame), the coin spins here and lands on
-- the side it rolled. a win pays CashGames.COINFLIP_MULTIPLIER x the bet.
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
local useSetting = require(script.Parent.Parent.Parent.Hooks.useSetting)

local e = React.createElement

-- the quickCashGames setting uses QUICK_FLIP_TIME
local QUICK_FLIP_TIME = 0.35
local FLIP_TIME = 1.2
local COIN_SIZE = 200
local HISTORY_HEIGHT = 56
local SIDES = {
	heads = { name = "Heads", letter = "H", color = Color3.fromRGB(245, 190, 60) },
	tails = { name = "Tails", letter = "T", color = Color3.fromRGB(180, 195, 210) },
}

local function other(side: string): string
	return if side == "heads" then "tails" else "heads"
end

local function CoinflipPage(props)
	local duration = if useSetting("quickCashGames") then QUICK_FLIP_TIME else FLIP_TIME
	local bet, setBet = React.useState(1000)
	local side, setSide = React.useState("heads")
	local flipping, setFlipping = React.useState(false)
	local outcome, setOutcome = React.useState(nil)
	local history, setHistory = React.useState({})
	-- the coin: how wide it looks mid spin (1 = facing you), and which face shows
	local squash, setSquash = React.useBinding(1)
	local face, setFace = React.useBinding("heads")
	local alive = React.useRef(true)

	React.useEffect(function()
		alive.current = true
		return function()
			alive.current = false
		end
	end, {})

	local multiplier = CashGames.COINFLIP_MULTIPLIER

	local function flip()
		if flipping then
			return
		elseif not CashGames.validBet(bet) then
			Parts.fail(`Bet between {Format.cash(CashGames.MIN_BET)} and {Format.cash(CashGames.MAX_BET)}`)
			return
		elseif bet > props.cash then
			Parts.fail("Not enough cash")
			return
		end
		local wager, pick = bet, side
		setFlipping(true)
		setOutcome(nil)
		Sfx.play("whoosh")
		task.spawn(function()
			local result = Actions.cashGame("coinflip", wager, pick)
			if not alive.current then
				return
			end
			if not result.ok then
				setFlipping(false)
				Parts.fail(result.err)
				return
			end
			local data = result.data
			-- spin a whole number of half turns so the coin lands on the side the server rolled
			local startFace = face:getValue()
			local halfTurns = 10 + (if startFace == data.result then 0 else 1)
			local started = os.clock()
			while alive.current do
				local p = math.clamp((os.clock() - started) / duration, 0, 1)
				local angle = (1 - (1 - p) ^ 3) * halfTurns * math.pi
				setSquash(math.max(math.abs(math.cos(angle)), 0.04))
				local flips = math.floor((angle + math.pi / 2) / math.pi)
				setFace(if flips % 2 == 0 then startFace else other(startFace))
				if p >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if not alive.current then
				return
			end
			setSquash(1)
			setFace(data.result)
			setOutcome({ won = data.won, payout = data.payout, bet = wager, result = data.result })
			setHistory(function(list)
				return Parts.pushHistory(list, { text = SIDES[data.result].letter, won = data.won })
			end)
			Parts.announce(data.won, wager, data.payout)
			setFlipping(false)
		end)
	end

	local function sideButton(id: string, layoutOrder: number)
		local info = SIDES[id]
		local picked = side == id
		return e(Button, {
			layoutOrder = layoutOrder,
			size = UDim2.new(0.5, -4, 1, 0),
			text = info.name,
			textSize = 17,
			color = if picked then info.color:Lerp(Theme.colors.panel, 0.35) else Theme.colors.panelLight,
			disabled = flipping,
			onClick = function()
				setSide(id)
			end,
		})
	end

	local resultText, resultColor = "Pick a side and flip", Theme.colors.textDim
	if flipping then
		resultText = "Flipping..."
	elseif outcome then
		resultText = if outcome.won
			then `{SIDES[outcome.result].name}! You won {Format.cash(outcome.payout)}`
			else `{SIDES[outcome.result].name}. You lost {Format.cash(outcome.bet)}`
		resultColor = if outcome.won then Parts.WIN else Parts.LOSE
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Panel = e(Parts.Panel, nil, {
			Bet = e(BetInput, {
				value = bet,
				onChange = setBet,
				cash = props.cash,
				disabled = flipping,
			}),
			SideLabel = e(Text, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Pick a side",
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				display = true,
			}),
			Sides = e("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Heads = sideButton("heads", 1),
				Tails = sideButton("tails", 2),
			}),
			Multiplier = e(Parts.Line, {
				layoutOrder = 4,
				label = "Multiplier",
				value = string.format("%.2fx", multiplier),
			}),
			Win = e(Parts.Line, {
				layoutOrder = 5,
				label = "Win",
				value = Format.cash(CashGames.payout(bet, multiplier)),
				color = Theme.colors.cash,
			}),
			Flip = e(Button, {
				layoutOrder = 6,
				size = UDim2.new(1, 0, 0, 48),
				text = if flipping then "Flipping..." else `Flip  ·  {Format.cash(bet)}`,
				textSize = 19,
				color = Theme.colors.good,
				disabled = flipping or bet > props.cash or not CashGames.validBet(bet),
				sound = false,
				onClick = flip,
			}),
			Note = e(Text, {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 16),
				Text = `50/50 · {math.floor(CashGames.HOUSE_EDGE * 100)}% house edge`,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
		}),
		Stage = e("Frame", {
			Position = UDim2.fromOffset(Parts.PANEL_WIDTH + 14, 0),
			Size = UDim2.new(1, -(Parts.PANEL_WIDTH + 14), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Coin = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -(HISTORY_HEIGHT / 2 + 24)),
				Size = squash:map(function(width)
					return UDim2.fromOffset(COIN_SIZE * width, COIN_SIZE)
				end),
				BackgroundColor3 = face:map(function(id)
					return SIDES[id].color
				end),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Rim = e("UIStroke", {
					Color = face:map(function(id)
						return SIDES[id].color:Lerp(Color3.new(0, 0, 0), 0.35)
					end),
					Thickness = 6,
				}),
				Shine = e("UIGradient", {
					Rotation = 45,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
				}),
				Letter = e(Text, {
					Size = UDim2.fromScale(1, 1),
					Text = face:map(function(id)
						return SIDES[id].letter
					end),
					TextSize = 96,
					TextColor3 = Color3.fromRGB(40, 36, 30),
					TextTransparency = squash:map(function(width)
						return if width < 0.35 then 1 else 0.15
					end),
					TextXAlignment = Enum.TextXAlignment.Center,
					display = true,
					weight = Enum.FontWeight.Bold,
				}),
			}),
			Result = e(Text, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, COIN_SIZE / 2 - HISTORY_HEIGHT / 2 - 6),
				Size = UDim2.new(1, 0, 0, 30),
				Text = resultText,
				TextSize = 24,
				TextColor3 = resultColor,
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

return CoinflipPage
