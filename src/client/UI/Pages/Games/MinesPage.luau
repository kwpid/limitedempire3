-- Mines: pick how many mines hide in the 5x5 grid, then reveal tiles. every safe one raises the multiplier, a mine
-- loses the bet, cash out any time after the first. the server places the mines (CashRoundService) and only tells
-- the page where they were once the round ends.
-- props: cash

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CashGames = require(Shared.Games.CashGames)
local Format = require(Shared.Util.Format)
local Mines = require(Shared.Games.Mines)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local BetInput = require(script.Parent.BetInput)
local Parts = require(script.Parent.CashGameParts)
local Actions = require(script.Parent.Parent.Parent.Parent.Controllers.Actions)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local HISTORY_HEIGHT = 56
local GAP = 8
local PRESETS = { 1, 3, 5, 10, 24 }
local GEM = Color3.fromRGB(90, 200, 140)
local MINE = Color3.fromRGB(220, 80, 70)

local function multiplierText(m: number): string
	return string.format("%.2fx", m)
end

-- tile states: "hidden", "gem" (found this round), "mine" (shown after the round), "boom" (the mine that ended it),
-- "safe" (never revealed, shown dim after the round)
local function Tile(props)
	local hovered, setHovered = React.useState(false)
	local state = props.state
	local clickable = props.onClick ~= nil
	local color = Theme.colors.panelLight
	if state == "gem" then
		color = GEM:Lerp(Theme.colors.panel, 0.35)
	elseif state == "boom" then
		color = MINE
	elseif state == "mine" then
		color = MINE:Lerp(Theme.colors.panel, 0.6)
	elseif state == "safe" then
		color = GEM:Lerp(Theme.colors.panel, 0.8)
	elseif hovered and clickable then
		color = Theme.colors.panelLight:Lerp(Color3.new(1, 1, 1), 0.12)
	end
	local symbol = if state == "gem" or state == "safe" then "💎" elseif state == "mine" or state == "boom" then "💣" else ""
	return e("TextButton", {
		LayoutOrder = props.tile,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = symbol,
		FontFace = Theme.font(Enum.FontWeight.Bold),
		TextScaled = true,
		TextColor3 = if state == "gem" or state == "safe" then GEM:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.new(1, 1, 1),
		TextTransparency = if state == "safe" or state == "mine" then 0.5 else 0,
		[React.Event.Activated] = function()
			if props.onClick then
				props.onClick(props.tile)
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", {
			Color = if hovered and clickable then Theme.colors.strokeLight else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.22, 0),
			PaddingLeft = UDim.new(0.22, 0),
			PaddingRight = UDim.new(0.22, 0),
		}),
	})
end

local function MinesPage(props)
	local bet, setBet = React.useState(1000)
	local mineCount, setMineCount = React.useState(3)
	local mineText, setMineText = React.useState("3")
	-- the running round: { bet, mines, gems = { [tile]: true }, safe }
	local round, setRound = React.useState(nil)
	-- the last finished round, to show its board: { gems, mines = { [tile]: true }, boom?, won, payout?, bet }
	local finished, setFinished = React.useState(nil)
	local pending, setPending = React.useState(false)
	local history, setHistory = React.useState({})

	-- pick up a round that was still running when the page was closed
	React.useEffect(function()
		task.spawn(function()
			local result = Actions.cashRound("mines", "state")
			if result.ok and result.data then
				local gems = {}
				for _, tile in result.data.revealed do
					gems[tile] = true
				end
				setRound({ bet = result.data.bet, mines = result.data.mines, gems = gems, safe = result.data.safe })
			end
		end)
	end, {})

	local function pickMines(value: number)
		local clamped = math.clamp(math.floor(value), Mines.MIN_MINES, Mines.MAX_MINES)
		setMineCount(clamped)
		setMineText(tostring(clamped))
	end

	local function finish(data, won: boolean, boom: number?)
		local mineSet = {}
		for _, tile in data.mines or {} do
			mineSet[tile] = true
		end
		local gems = round and round.gems or {}
		setFinished({ gems = gems, mines = mineSet, boom = boom, won = won, payout = data.payout, bet = round and round.bet or bet })
		setRound(nil)
		setHistory(function(list)
			return Parts.pushHistory(list, {
				text = if won then multiplierText(data.multiplier) else "Boom",
				won = won,
			})
		end)
	end

	local function start()
		if round or pending then
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
			local result = Actions.cashRound("mines", "start", { bet = bet, mines = mineCount })
			setPending(false)
			if result.ok then
				Sfx.play("whoosh")
				setFinished(nil)
				setRound({ bet = bet, mines = mineCount, gems = {}, safe = 0 })
			else
				Parts.fail(result.err)
			end
		end)
	end

	local function reveal(tile: number)
		if not round or pending or round.gems[tile] then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.cashRound("mines", "reveal", { tile = tile })
			setPending(false)
			if not result.ok then
				Parts.fail(result.err)
				return
			end
			local data = result.data
			if not data.safe then
				Sfx.play("error")
				finish(data, false, tile)
				return
			end
			Sfx.play("tick")
			local gems = table.clone(round.gems)
			gems[tile] = true
			local nextRound = table.clone(round)
			nextRound.gems = gems
			nextRound.safe = data.revealed
			setRound(nextRound)
			if data.payout then
				-- every safe tile found, the server cashed out
				round = nextRound
				Parts.announce(true, nextRound.bet, data.payout)
				finish(data, true)
			end
		end)
	end

	local function cashOut()
		if not round or round.safe == 0 or pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.cashRound("mines", "cashout")
			setPending(false)
			if result.ok then
				Parts.announce(true, round.bet, result.data.payout)
				finish(result.data, true)
			else
				Parts.fail(result.err)
			end
		end)
	end

	local tiles = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / Mines.SIDE, -GAP * (Mines.SIDE - 1) / Mines.SIDE, 1 / Mines.SIDE, -GAP * (Mines.SIDE - 1) / Mines.SIDE),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for tile = 1, Mines.TILES do
		local state = "hidden"
		if round then
			state = if round.gems[tile] then "gem" else "hidden"
		elseif finished then
			if finished.boom == tile then
				state = "boom"
			elseif finished.mines[tile] then
				state = "mine"
			elseif finished.gems[tile] then
				state = "gem"
			else
				state = "safe"
			end
		end
		tiles["Tile" .. tile] = e(Tile, {
			tile = tile,
			state = state,
			onClick = if round and state == "hidden" then reveal else nil,
		})
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
			text = tostring(value),
			textSize = 14,
			color = if mineCount == value then Theme.colors.accent else Theme.colors.panelLight,
			disabled = round ~= nil,
			onClick = function()
				pickMines(value)
			end,
		})
	end

	local activeMines = if round then round.mines else mineCount
	local safeFound = if round then round.safe else 0
	local current = Mines.multiplier(activeMines, safeFound)
	local nextMultiplier = Mines.multiplier(activeMines, safeFound + 1)
	local roundBet = if round then round.bet else bet

	local status = `{mineCount} mines hidden in {Mines.TILES} tiles`
	if round then
		status = if round.safe > 0
			then `{round.safe} safe · cash out {Format.cash(CashGames.payout(round.bet, current))}`
			else "Pick a tile"
	elseif finished then
		status = if finished.won
			then `You won {Format.cash(finished.payout or 0)}`
			else `Boom! You lost {Format.cash(finished.bet)}`
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
				disabled = round ~= nil,
			}),
			MinesLabel = e(Text, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Mines",
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				display = true,
			}),
			Count = e("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Input = e("TextBox", {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -24, 1, 0),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					TextEditable = round == nil,
					Text = mineText,
					TextColor3 = Theme.colors.text,
					FontFace = Theme.font(Enum.FontWeight.Bold),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					[React.Change.Text] = function(box: TextBox)
						setMineText(box.Text)
						local value = tonumber(box.Text)
						if value and Mines.validMines(value) then
							setMineCount(value)
						end
					end,
					[React.Event.FocusLost] = function(box: TextBox)
						pickMines(tonumber(box.Text) or mineCount)
					end,
				}),
			}),
			Presets = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
			}, presets),
			Next = e(Parts.Line, {
				layoutOrder = 5,
				label = "Next tile",
				value = if nextMultiplier > 0 then multiplierText(nextMultiplier) else "-",
			}),
			Current = e(Parts.Line, {
				layoutOrder = 6,
				label = "Cash out",
				value = Format.cash(CashGames.payout(roundBet, current)),
				color = Theme.colors.cash,
			}),
			Action = if round
				then e(Button, {
					layoutOrder = 7,
					size = UDim2.new(1, 0, 0, 48),
					text = if round.safe > 0 then `Cash out  ·  {multiplierText(current)}` else "Pick a tile",
					textSize = 19,
					color = Theme.colors.cash:Lerp(Theme.colors.panel, 0.3),
					disabled = pending or round.safe == 0,
					sound = false,
					onClick = cashOut,
				})
				else e(Button, {
					layoutOrder = 7,
					size = UDim2.new(1, 0, 0, 48),
					text = if pending then "Starting..." else `Start  ·  {Format.cash(bet)}`,
					textSize = 19,
					color = Theme.colors.good,
					disabled = pending or bet > props.cash or not CashGames.validBet(bet),
					sound = false,
					onClick = start,
				}),
			Note = e(Text, {
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 16),
				Text = `{Mines.MIN_MINES} to {Mines.MAX_MINES} mines · {math.floor(CashGames.HOUSE_EDGE * 100)}% house edge`,
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
		}),
		Stage = e("Frame", {
			Position = UDim2.fromOffset(Parts.PANEL_WIDTH + 14, 0),
			Size = UDim2.new(1, -(Parts.PANEL_WIDTH + 14), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Board = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(1, 0, 1, -(HISTORY_HEIGHT + 44)),
				BackgroundTransparency = 1,
			}, {
				Square = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Grid = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}, tiles),
			}),
			Status = e(Text, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -(HISTORY_HEIGHT + 8)),
				Size = UDim2.new(1, 0, 0, 28),
				Text = status,
				TextSize = 20,
				TextColor3 = if finished and not round
					then (if finished.won then Parts.WIN else Parts.LOSE)
					else Theme.colors.textDim,
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

return MinesPage
