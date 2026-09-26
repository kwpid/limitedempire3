-- the top 100 leaderboards, in tab order. LeaderboardService keeps them, the season window shows them.
-- stat = a lifetime stat id from Shared/PlayerStats; season, level and value are worked out by LeaderboardService.
-- format: "sp", "level" (score is xp), "cash" or "count".
-- api: Leaderboards.list, Leaderboards.get(id)

export type Board = { id: string, name: string, format: string, stat: string? }

local Leaderboards = {}

Leaderboards.list = {
	{ id = "season", name = "Season Points", format = "sp" },
	{ id = "level", name = "Level", format = "level" },
	{ id = "value", name = "Inventory Value", format = "cash" },
	{ id = "opened", name = "Cases Opened", format = "count", stat = "opened" },
	{ id = "unboxedValue", name = "Value Unboxed", format = "cash", stat = "unboxedValue" },
	{ id = "bestValue", name = "Best Unbox", format = "cash", stat = "bestValue" },
	{ id = "battlesWon", name = "Battles Won", format = "count", stat = "battlesWon" },
	{ id = "hiloBest", name = "Hi-Lo Streak", format = "count", stat = "hiloBest" },
} :: { Board }

local byId: { [string]: Board } = {}
for _, board in Leaderboards.list do
	byId[board.id] = board
end

function Leaderboards.get(id: string): Board?
	return byId[id]
end

return Leaderboards
