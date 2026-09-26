-- games played straight with cash: Coinflip and Dice. the server rolls (GameService), this holds the rules so the ui
-- shows the same numbers. both keep a HOUSE_EDGE: a fair bet would pay 1 / chance, these pay (1 - edge) / chance.
--   coinflip: pick heads or tails, a win pays COINFLIP_MULTIPLIER x the bet
--   dice: pick a win chance (whole percent, MIN_CHANCE to MAX_CHANCE), a roll from 0 to 100 under it wins and pays
--   Dice.multiplier(chance) x the bet
-- api: CashGames.MIN_BET, MAX_BET, HOUSE_EDGE, COINFLIP_MULTIPLIER, MIN_CHANCE, MAX_CHANCE,
-- CashGames.diceMultiplier(chance) -> number, CashGames.payout(bet, multiplier) -> number, CashGames.validBet(bet)

local CashGames = {}

CashGames.MIN_BET = 100
CashGames.MAX_BET = 5_000_000
CashGames.HOUSE_EDGE = 0.02
CashGames.COINFLIP_MULTIPLIER = 2 * (1 - CashGames.HOUSE_EDGE)
CashGames.MIN_CHANCE = 2
CashGames.MAX_CHANCE = 95

function CashGames.diceMultiplier(chance: number): number
	return (1 - CashGames.HOUSE_EDGE) * 100 / chance
end

function CashGames.payout(bet: number, multiplier: number): number
	return math.floor(bet * multiplier)
end

function CashGames.validBet(bet: any): boolean
	return type(bet) == "number"
		and bet == bet
		and bet % 1 == 0
		and bet >= CashGames.MIN_BET
		and bet <= CashGames.MAX_BET
end

function CashGames.validChance(chance: any): boolean
	return type(chance) == "number"
		and chance % 1 == 0
		and chance >= CashGames.MIN_CHANCE
		and chance <= CashGames.MAX_CHANCE
end

return CashGames
