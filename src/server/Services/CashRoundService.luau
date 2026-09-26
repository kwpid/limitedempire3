-- cash games that play out over a round: Crash and Mines (rules in Shared/Games/Crash and Shared/Games/Mines).
-- one round per player per game. the bet is taken when the round starts, the outcome is rolled right then on the
-- server, and everything the client sends is checked against the server's own state and clock.
--
-- client calls Net.functions.CashRound:InvokeServer(game, action, payload) -> { ok, err?, data }:
--   ("crash", "start", { bet, auto? })  -> {}           the round runs from now
--   ("crash", "cashout")                -> { multiplier, payout }
--   ("mines", "start", { bet, mines })  -> {}
--   ("mines", "reveal", { tile })       -> { safe, multiplier, revealed, mines? (all mine tiles when it ends) }
--   ("mines", "cashout")                -> { multiplier, payout, mines }
--   (game, "state")                     -> the running round, if any (after reopening the page)
-- and pushes Net.events.CashRoundUpdate(game, event) for things that happen on their own:
--   crash: { kind = "crash", crash } when it crashes, { kind = "cashout", multiplier, payout } for an auto cash out
--
-- leaving mid-round: a mines round is cashed out (or refunded with nothing revealed), a crash round pays its auto
-- cash out if the round would have reached it, otherwise it is lost like any bet that wasn't cashed out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CashGames = require(Shared.Games.CashGames)
local Crash = require(Shared.Games.Crash)
local Mines = require(Shared.Games.Mines)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CashRoundService = {}

local ACTION_COOLDOWN = 0.08

type CrashRound = {
	bet: number,
	crash: number,
	startedAt: number,
	auto: number?,
	cashedOut: boolean,
	threads: { thread },
}
type MinesRound = { bet: number, mines: { [number]: boolean }, count: number, revealed: { [number]: boolean }, safe: number }

local rng = Random.new()
local crashRounds: { [Player]: CrashRound } = {}
local minesRounds: { [Player]: MinesRound } = {}
local lastAction: { [Player]: number } = {}

local function fail(err: string): Types.Result<any>
	return { ok = false, err = err }
end

local function pay(player: Player, bet: number, multiplier: number): number
	local payout = CashGames.payout(bet, multiplier)
	if payout > 0 then
		PlayerDataService:AddCash(player, payout)
		PlayerDataService:AddStats(player, { cashWon = payout })
	end
	return payout
end

local function takeBet(player: Player, bet: any): string?
	if not CashGames.validBet(bet) then
		return `Bet between {CashGames.MIN_BET} and {CashGames.MAX_BET}`
	end
	if not PlayerDataService:TrySpend(player, bet) then
		return "Not enough cash"
	end
	PlayerDataService:AddStats(player, { cashBets = 1, cashWagered = bet })
	return nil
end

local function send(player: Player, gameId: string, event)
	if player.Parent == Players then
		Net.events.CashRoundUpdate:FireClient(player, gameId, event)
	end
end

-- crash ------------------------------------------------------------------------------------------------------------

local function crashElapsed(round: CrashRound): number
	return os.clock() - round.startedAt
end

local function endCrash(player: Player, round: CrashRound)
	if crashRounds[player] == round then
		crashRounds[player] = nil
	end
	for _, thread in round.threads do
		if coroutine.running() ~= thread then
			pcall(task.cancel, thread)
		end
	end
end

local crash = {}

function crash.start(player: Player, payload): Types.Result<any>
	if crashRounds[player] then
		return fail("A round is already running")
	end
	local auto = payload.auto
	if auto ~= nil and not Crash.validAuto(auto) then
		return fail(`Auto cash out from {Crash.MIN_AUTO}x to {Crash.MAX}x`)
	end
	local err = takeBet(player, payload.bet)
	if err then
		return fail(err)
	end
	local round: CrashRound = {
		bet = payload.bet,
		crash = Crash.roll(rng:NextNumber()),
		startedAt = os.clock(),
		auto = auto,
		cashedOut = false,
		threads = {},
	}
	crashRounds[player] = round
	if auto and auto < round.crash then
		table.insert(
			round.threads,
			task.delay(Crash.timeFor(auto), function()
				if crashRounds[player] ~= round or round.cashedOut then
					return
				end
				round.cashedOut = true
				local payout = pay(player, round.bet, auto)
				send(player, "crash", { kind = "cashout", multiplier = auto, payout = payout })
			end)
		)
	end
	table.insert(
		round.threads,
		task.delay(Crash.timeFor(round.crash), function()
			if crashRounds[player] ~= round then
				return
			end
			endCrash(player, round)
			send(player, "crash", { kind = "crash", crash = Crash.display(round.crash) })
		end)
	)
	return { ok = true, data = {} }
end

function crash.cashout(player: Player): Types.Result<any>
	local round = crashRounds[player]
	if not round or round.cashedOut then
		return fail("No round to cash out")
	end
	local multiplier = Crash.multiplierAt(crashElapsed(round))
	if multiplier >= round.crash then
		return fail("Too late, it crashed")
	end
	round.cashedOut = true
	local payout = pay(player, round.bet, multiplier)
	-- the round keeps going until it crashes, so the player still sees where it would have ended
	return { ok = true, data = { multiplier = multiplier, payout = payout } }
end

function crash.state(player: Player): Types.Result<any>
	local round = crashRounds[player]
	if not round then
		return { ok = true, data = nil }
	end
	return {
		ok = true,
		data = { bet = round.bet, elapsed = crashElapsed(round), auto = round.auto, cashedOut = round.cashedOut },
	}
end

-- mines ------------------------------------------------------------------------------------------------------------

local function mineList(round: MinesRound): { number }
	local list = {}
	for tile in round.mines do
		table.insert(list, tile)
	end
	table.sort(list)
	return list
end

local mines = {}

function mines.start(player: Player, payload): Types.Result<any>
	if minesRounds[player] then
		return fail("A round is already running")
	end
	if not Mines.validMines(payload.mines) then
		return fail(`Pick {Mines.MIN_MINES} to {Mines.MAX_MINES} mines`)
	end
	local err = takeBet(player, payload.bet)
	if err then
		return fail(err)
	end
	-- shuffle the tiles and mine the first ones
	local tiles = {}
	for tile = 1, Mines.TILES do
		tiles[tile] = tile
	end
	for i = Mines.TILES, 2, -1 do
		local j = rng:NextInteger(1, i)
		tiles[i], tiles[j] = tiles[j], tiles[i]
	end
	local placed = {}
	for i = 1, payload.mines do
		placed[tiles[i]] = true
	end
	minesRounds[player] = { bet = payload.bet, mines = placed, count = payload.mines, revealed = {}, safe = 0 }
	return { ok = true, data = {} }
end

local function cashOutMines(player: Player, round: MinesRound): (number, number)
	minesRounds[player] = nil
	local multiplier = Mines.multiplier(round.count, round.safe)
	return multiplier, pay(player, round.bet, multiplier)
end

function mines.reveal(player: Player, payload): Types.Result<any>
	local round = minesRounds[player]
	local tile = payload.tile
	if not round then
		return fail("Start a round first")
	elseif type(tile) ~= "number" or tile % 1 ~= 0 or tile < 1 or tile > Mines.TILES then
		return fail("Invalid tile")
	elseif round.revealed[tile] then
		return fail("Already revealed")
	end
	round.revealed[tile] = true
	if round.mines[tile] then
		minesRounds[player] = nil
		return { ok = true, data = { safe = false, multiplier = 0, revealed = round.safe, mines = mineList(round) } }
	end
	round.safe += 1
	-- every safe tile found: cash out for the player
	if round.safe >= Mines.TILES - round.count then
		local multiplier, payout = cashOutMines(player, round)
		return {
			ok = true,
			data = {
				safe = true,
				multiplier = multiplier,
				revealed = round.safe,
				payout = payout,
				mines = mineList(round),
			},
		}
	end
	return {
		ok = true,
		data = { safe = true, multiplier = Mines.multiplier(round.count, round.safe), revealed = round.safe },
	}
end

function mines.cashout(player: Player): Types.Result<any>
	local round = minesRounds[player]
	if not round or round.safe == 0 then
		return fail("Reveal a tile first")
	end
	local multiplier, payout = cashOutMines(player, round)
	return { ok = true, data = { multiplier = multiplier, payout = payout, mines = mineList(round) } }
end

function mines.state(player: Player): Types.Result<any>
	local round = minesRounds[player]
	if not round then
		return { ok = true, data = nil }
	end
	local revealed = {}
	for tile in round.revealed do
		table.insert(revealed, tile)
	end
	return { ok = true, data = { bet = round.bet, mines = round.count, revealed = revealed, safe = round.safe } }
end

local GAMES = { crash = crash, mines = mines }

-- leaving mid-round (runs before the player's data is saved)
local function settle(player: Player)
	local crashRound = crashRounds[player]
	if crashRound then
		if not crashRound.cashedOut and crashRound.auto and crashRound.auto < crashRound.crash then
			crashRound.cashedOut = true
			pay(player, crashRound.bet, crashRound.auto)
		end
		endCrash(player, crashRound)
	end
	local minesRound = minesRounds[player]
	if minesRound then
		if minesRound.safe > 0 then
			cashOutMines(player, minesRound)
		else
			minesRounds[player] = nil
			PlayerDataService:AddCash(player, minesRound.bet)
			PlayerDataService:AddStats(player, { cashBets = -1, cashWagered = -minesRound.bet })
		end
	end
end

function CashRoundService:Init()
	Net.functions.CashRound.OnServerInvoke = function(player: Player, gameId: any, action: any, payload: any)
		local handlers = type(gameId) == "string" and GAMES[gameId]
		local handler = handlers and type(action) == "string" and handlers[action]
		if not handler then
			return fail("Invalid request")
		end
		local now = os.clock()
		if lastAction[player] and now - lastAction[player] < ACTION_COOLDOWN then
			return fail("Slow down a little")
		end
		lastAction[player] = now
		if not PlayerDataService:GetData(player) then
			return fail("Your data is still loading")
		end
		local ok, result = pcall(handler, player, if type(payload) == "table" then payload else {})
		if not ok then
			warn(`[CashRoundService] {gameId} {action} failed for {player.Name}: {result}`)
			return fail("Something went wrong")
		end
		return result
	end
	PlayerDataService.Leaving:Connect(settle)
	-- rounds are cleared by settle (on Leaving, before the data saves), not here: PlayerRemoving handlers can run in
	-- any order, and clearing a round first would lose its payout
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return CashRoundService
