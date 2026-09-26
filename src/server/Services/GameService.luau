-- the single player games in the Games tab. every outcome is rolled here, the rules and odds live in
-- Shared/Games so the ui shows the same numbers. equipped and pinned items can never be used, and custom items
-- can't be put into the upgrader or a trade-up.
-- api (client calls through Net.functions):
--   Upgrade(uids, targetAssetId) -> { ok, err?, data = { won, chance, roll, item? } }
--   TradeUp(uids) -> { ok, err?, data = item }
--   HiLoStart() -> { ok, data = round }, HiLoGuess("higher" | "lower") -> { ok, err?, data = result }
--   CashGame("coinflip", bet, "heads" | "tails") / CashGame("dice", bet, chance) -> { ok, err?, data = { won,
--   payout, multiplier, result } } (result is the side the coin landed on, or the dice roll 0 to 100)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Career = require(Shared.Progress.Career)
local HigherLower = require(Shared.Games.HigherLower)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)
local TradeUp = require(Shared.Games.TradeUp)
local CashGames = require(Shared.Games.CashGames)
local Types = require(Shared.Types)
local Upgrader = require(Shared.Games.Upgrader)
local Valuation = require(Shared.Modifiers.Valuation)
local ItemFactory = require(ServerScriptService.Server.Modules.ItemFactory)
local ItemModelService = require(script.Parent.ItemModelService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressService = require(script.Parent.ProgressService)
local BoostService = require(script.Parent.BoostService)

local GameService = {}

local rng = Random.new()
local busy: { [Player]: boolean } = {}

-- cash games settle instantly, this just stops a player firing bets faster than the ui can show them
local CASH_GAME_COOLDOWN = 0.35
local lastCashGame: { [Player]: number } = {}

type HiLoRound = { left: number, right: number, streak: number }
local hilo: { [Player]: HiLoRound } = {}

local function fail(err: string): Types.Result<any>
	return { ok = false, err = err }
end

-- unique owned items that are not equipped or pinned (and not custom)
local function takeableItems(player: Player, uids: any, maxCount: number): ({ Types.ItemInstance }?, string?)
	if type(uids) ~= "table" or #uids == 0 or #uids > maxCount then
		return nil, "Invalid selection"
	end
	local state = PlayerDataService:Get(player)
	if not state then
		return nil, "Your data isn't loaded yet"
	end
	local items, seen = {}, {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return nil, "Invalid selection"
		end
		seen[uid] = true
		local item = state.inventory[uid]
		if not item then
			return nil, "You no longer have one of those items"
		end
		if table.find(state.equipped, uid) or table.find(state.pinned or {}, uid) then
			return nil, "Unequip and unpin items before using them"
		end
		if ItemRegistry.isCustom(item.assetId) then
			return nil, "Custom items can't be used here"
		end
		table.insert(items, item)
	end
	return items, nil
end

local function locked(player: Player, fn: () -> Types.Result<any>): Types.Result<any>
	if busy[player] then
		return fail("Slow down")
	end
	busy[player] = true
	local ok, result = pcall(fn)
	busy[player] = nil
	if not ok then
		warn(`[GameService] {player.Name}: {result}`)
		return fail("Something went wrong")
	end
	return result
end

local function uidsOf(items: { Types.ItemInstance }): { string }
	local uids = {}
	for _, item in items do
		table.insert(uids, item.uid)
	end
	return uids
end

function GameService:Upgrade(player: Player, uids: any, targetAssetId: any): Types.Result<any>
	return locked(player, function()
		local items, err = takeableItems(player, uids, Upgrader.MAX_INPUTS)
		if not items then
			return fail(err :: string)
		end
		if type(targetAssetId) ~= "number" or not Upgrader.canTarget(targetAssetId) then
			return fail("Pick a target item")
		end
		local inputValue = 0
		for _, item in items do
			inputValue += Valuation.value(item)
		end
		local chance = Upgrader.chance(inputValue, ItemRegistry.baseValue(targetAssetId))
		if chance <= 0 then
			return fail("Pick a target worth more than what you put in (at least a 1% chance)")
		end

		local roll = rng:NextNumber()
		local won = roll < chance
		local item = nil
		if won then
			item = ItemFactory.create(targetAssetId, nil, 1, player, { traits = {}, tracker = false })
			ItemModelService:Prepare(targetAssetId)
		end
		PlayerDataService:RemoveItems(player, uidsOf(items))
		if item then
			PlayerDataService:AddItem(player, item)
		end
		PlayerDataService:AddStats(player, { upgrades = 1, upgradesWon = if won then 1 else 0 })
		ProgressService:Track(player, "upgrades", 1, Career.XP.upgrade)
		if won then
			ProgressService:Track(player, "upgradeWins", 1, Career.XP.upgradeWin)
		end
		return { ok = true, data = { won = won, chance = chance, roll = roll, item = item } }
	end)
end

function GameService:TradeUp(player: Player, uids: any): Types.Result<any>
	return locked(player, function()
		local items, err = takeableItems(player, uids, TradeUp.COUNT)
		if not items then
			return fail(err :: string)
		end
		local ok, checkErr = TradeUp.check(items)
		if not ok then
			return fail(checkErr :: string)
		end
		local nextTier = TradeUp.nextTier(ItemRegistry.tier(items[1].assetId).id) :: any
		local ticket = items[rng:NextInteger(1, #items)]
		local pool = TradeUp.pool(CaseRegistry.itemSeries(ticket), nextTier.id, TradeUp.maxValue(items))
		local assetId = pool[rng:NextInteger(1, #pool)]

		local item = ItemFactory.create(assetId, nil, 1, player, {
			traits = {},
			tracker = false,
			float = TradeUp.float(items),
		})
		ItemModelService:Prepare(assetId)
		PlayerDataService:RemoveItems(player, uidsOf(items))
		PlayerDataService:AddItem(player, item)
		PlayerDataService:AddStats(player, { tradeUps = 1 })
		ProgressService:Track(player, "tradeUps", 1, Career.XP.tradeUp)
		return { ok = true, data = item }
	end)
end

-- a random catalog item worth within MAX_RATIO of the given value, but not the same value
local function pickNear(value: number, avoid: number?): number
	local targets = Upgrader.targets()
	for _ = 1, 60 do
		local assetId = targets[rng:NextInteger(1, #targets)]
		local other = ItemRegistry.baseValue(assetId)
		if
			assetId ~= avoid
			and other ~= value
			and other >= value / HigherLower.MAX_RATIO
			and other <= value * HigherLower.MAX_RATIO
		then
			return assetId
		end
	end
	return targets[rng:NextInteger(1, #targets)]
end

local function hiloView(player: Player, round: HiLoRound)
	local daily = PlayerDataService:GetDaily(player, HigherLower.today())
	return {
		left = { assetId = round.left, value = ItemRegistry.baseValue(round.left) },
		right = { assetId = round.right },
		streak = round.streak,
		earnedToday = daily and daily.hiloEarned or 0,
	}
end

function GameService:HiLoStart(player: Player): Types.Result<any>
	local targets = Upgrader.targets()
	local left = targets[rng:NextInteger(1, #targets)]
	local round = { left = left, right = pickNear(ItemRegistry.baseValue(left), left), streak = 0 }
	hilo[player] = round
	return { ok = true, data = hiloView(player, round) }
end

function GameService:HiLoGuess(player: Player, choice: any): Types.Result<any>
	local round = hilo[player]
	if not round then
		return fail("Start a game first")
	end
	if choice ~= "higher" and choice ~= "lower" then
		return fail("Invalid guess")
	end
	local leftValue = ItemRegistry.baseValue(round.left)
	local rightValue = ItemRegistry.baseValue(round.right)
	local correct = if choice == "higher" then rightValue > leftValue else rightValue < leftValue

	if not correct then
		hilo[player] = nil
		return { ok = true, data = { correct = false, rightValue = rightValue, streak = round.streak } }
	end

	round.streak += 1
	local daily = PlayerDataService:GetDaily(player, HigherLower.today())
	local reward = 0
	if daily then
		reward = math.max(0, math.min(HigherLower.reward(round.streak), HigherLower.DAILY_CAP - daily.hiloEarned))
		daily.hiloEarned += reward
	end
	if reward > 0 then
		-- a cash boost pays extra on top, the daily cap counts the base reward
		reward = math.floor(reward * BoostService:Multiplier(player, "cash"))
		PlayerDataService:AddCash(player, reward)
	end
	local state = PlayerDataService:Get(player)
	if state and round.streak > (state.stats.hiloBest or 0) then
		PlayerDataService:SetStats(player, { hiloBest = round.streak })
	end
	ProgressService:Track(player, "hiloStreak", round.streak, Career.XP.hiloCorrect)

	round.left = round.right
	round.right = pickNear(rightValue, round.left)
	return {
		ok = true,
		data = {
			correct = true,
			rightValue = rightValue,
			streak = round.streak,
			reward = reward,
			next = hiloView(player, round),
		},
	}
end

function GameService:CashGame(player: Player, gameId: any, bet: any, option: any): Types.Result<any>
	if not CashGames.validBet(bet) then
		return fail(`Bet between {CashGames.MIN_BET} and {CashGames.MAX_BET}`)
	end
	local multiplier
	if gameId == "coinflip" then
		if option ~= "heads" and option ~= "tails" then
			return fail("Pick heads or tails")
		end
		multiplier = CashGames.COINFLIP_MULTIPLIER
	elseif gameId == "dice" then
		if not CashGames.validChance(option) then
			return fail(`Pick a chance from {CashGames.MIN_CHANCE}% to {CashGames.MAX_CHANCE}%`)
		end
		multiplier = CashGames.diceMultiplier(option)
	else
		return fail("Invalid game")
	end
	local now = os.clock()
	if lastCashGame[player] and now - lastCashGame[player] < CASH_GAME_COOLDOWN then
		return fail("Slow down a little")
	end
	lastCashGame[player] = now
	if not PlayerDataService:TrySpend(player, bet) then
		return fail("Not enough cash")
	end

	local won, result
	if gameId == "coinflip" then
		result = if rng:NextNumber() < 0.5 then "heads" else "tails"
		won = result == option
	else
		-- two decimals, like the ui shows. rolling under the chance wins
		result = math.floor(rng:NextNumber() * 10000) / 100
		won = result < option
	end
	local payout = if won then CashGames.payout(bet, multiplier) else 0
	if payout > 0 then
		PlayerDataService:AddCash(player, payout)
	end
	PlayerDataService:AddStats(player, { cashBets = 1, cashWagered = bet, cashWon = payout })
	return { ok = true, data = { won = won, payout = payout, multiplier = multiplier, result = result } }
end

function GameService:Init()
	Net.functions.Upgrade.OnServerInvoke = function(player, uids, targetAssetId)
		return GameService:Upgrade(player, uids, targetAssetId)
	end
	Net.functions.TradeUp.OnServerInvoke = function(player, uids)
		return GameService:TradeUp(player, uids)
	end
	Net.functions.HiLoStart.OnServerInvoke = function(player)
		return GameService:HiLoStart(player)
	end
	Net.functions.HiLoGuess.OnServerInvoke = function(player, choice)
		return GameService:HiLoGuess(player, choice)
	end
	Net.functions.CashGame.OnServerInvoke = function(player, gameId, bet, option)
		return GameService:CashGame(player, gameId, bet, option)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		hilo[player] = nil
		lastCashGame[player] = nil
	end)
end

return GameService
