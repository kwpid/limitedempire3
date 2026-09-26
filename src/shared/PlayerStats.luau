-- lifetime stats kept for every player (saved with their data, shown in the settings window).
-- the server updates them in CaseService, InventoryService, GameService and IncomeService.
-- api: PlayerStats.list (ordered, { id, label, format = "count" | "cash" | "item" }), PlayerStats.defaults()

local PlayerStats = {}

PlayerStats.list = {
	{ id = "opened", label = "Cases opened", format = "count" },
	{ id = "spent", label = "Spent on cases", format = "cash" },
	{ id = "unboxedValue", label = "Total value unboxed", format = "cash" },
	{ id = "bestValue", label = "Best unbox", format = "cash" },
	{ id = "bestAssetId", label = "Best unbox item", format = "item" },
	{ id = "traits", label = "Traits found", format = "count" },
	{ id = "stacked", label = "Stacked traits found", format = "count" },
	{ id = "trackers", label = "Stat trackers found", format = "count" },
	{ id = "specials", label = "Rare special items", format = "count" },
	{ id = "sold", label = "Items sold", format = "count" },
	{ id = "soldValue", label = "Earned from selling", format = "cash" },
	{ id = "autoSold", label = "Items auto-sold", format = "count" },
	{ id = "upgrades", label = "Upgrades tried", format = "count" },
	{ id = "upgradesWon", label = "Upgrades won", format = "count" },
	{ id = "tradeUps", label = "Trade-ups", format = "count" },
	{ id = "hiloBest", label = "Best Higher or Lower streak", format = "count" },
	{ id = "battles", label = "Case battles", format = "count" },
	{ id = "battlesWon", label = "Case battles won", format = "count" },
	{ id = "cashBets", label = "Coinflip and dice bets", format = "count" },
	{ id = "cashWagered", label = "Wagered on coinflip and dice", format = "cash" },
	{ id = "cashWon", label = "Won from coinflip and dice", format = "cash" },
	{ id = "passiveEarned", label = "Passive income earned", format = "cash" },
}

function PlayerStats.defaults(): { [string]: number }
	local values = {}
	for _, stat in PlayerStats.list do
		values[stat.id] = 0
	end
	return values
end

return PlayerStats
