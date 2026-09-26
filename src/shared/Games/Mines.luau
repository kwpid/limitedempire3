-- Mines: a TILES grid hides some mines. reveal tiles one at a time: every safe one raises the multiplier, a mine
-- loses the bet. cash out any time after the first safe tile. the multiplier is the fair odds of surviving that many
-- picks, times (1 - edge). the server places the mines (CashRoundService).
-- api: Mines.TILES, SIDE, MIN_MINES, MAX_MINES, Mines.multiplier(mines, revealed), Mines.validMines(count)

local CashGames = require(script.Parent.CashGames)

local Mines = {}

Mines.SIDE = 5
Mines.TILES = Mines.SIDE * Mines.SIDE
Mines.MIN_MINES = 1
Mines.MAX_MINES = Mines.TILES - 1

function Mines.multiplier(mines: number, revealed: number): number
	if revealed <= 0 then
		return 1
	elseif revealed > Mines.TILES - mines then
		return 0
	end
	local odds = 1
	for i = 0, revealed - 1 do
		odds *= (Mines.TILES - i) / (Mines.TILES - mines - i)
	end
	return math.floor(odds * (1 - CashGames.HOUSE_EDGE) * 100) / 100
end

function Mines.validMines(count: any): boolean
	return type(count) == "number" and count % 1 == 0 and count >= Mines.MIN_MINES and count <= Mines.MAX_MINES
end

return Mines
