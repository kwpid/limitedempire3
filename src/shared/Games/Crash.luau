-- Crash: the multiplier climbs from 1.00x (GROWTH per second, exponentially) until it crashes at a point the server
-- rolled before the round started. cash out before it crashes to win bet x multiplier, or set an auto cash out.
-- crash points follow P(crash > x) = (1 - edge) / x, so every strategy returns (1 - edge) on average. a round can
-- crash instantly at 1.00x. the server decides cash outs by its own clock (CashRoundService).
-- the rolled point is kept exact for deciding wins (a cash out at m wins when m < crash), and shown rounded down.
-- api: Crash.GROWTH, MAX, MIN_AUTO, Crash.multiplierAt(seconds), Crash.timeFor(multiplier), Crash.roll(u) -> exact
-- crash point for a uniform u in [0, 1), Crash.display(point) -> rounded down to 2 decimals, Crash.validAuto(value)

local CashGames = require(script.Parent.CashGames)

local Crash = {}

Crash.GROWTH = 0.09
Crash.MAX = 1000
Crash.MIN_AUTO = 1.01

-- two decimals, rounded down, like everything shows it
function Crash.multiplierAt(seconds: number): number
	return math.min(math.floor(math.exp(Crash.GROWTH * math.max(seconds, 0)) * 100) / 100, Crash.MAX)
end

function Crash.timeFor(multiplier: number): number
	return math.log(math.max(multiplier, 1)) / Crash.GROWTH
end

function Crash.roll(u: number): number
	return math.clamp((1 - CashGames.HOUSE_EDGE) / (1 - u), 1, Crash.MAX)
end

function Crash.display(point: number): number
	return math.floor(point * 100) / 100
end

function Crash.validAuto(value: any): boolean
	return type(value) == "number" and value == value and value >= Crash.MIN_AUTO and value <= Crash.MAX
end

return Crash
