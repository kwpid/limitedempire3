-- lifetime stats kept for every player (saved with their data, shown in the settings window).
-- the server updates them in CaseService, InventoryService, GameService, TradeService and IncomeService.
-- api: PlayerStats.list (ordered, { id, label, group, format = "count" | "cash" | "item" }),
-- PlayerStats.groups (ordered group names), PlayerStats.defaults()

local PlayerStats = {}

PlayerStats.groups = { "Cases", "Items", "Selling", "Games", "Cash games", "Trading", "Income" }

PlayerStats.list = {
	{ id = "opened", group = "Cases", label = "Cases opened", format = "count" },
	{ id = "spent", group = "Cases", label = "Spent on cases", format = "cash" },
	{ id = "unboxedValue", group = "Cases", label = "Total value unboxed", format = "cash" },
	{ id = "bestValue", group = "Cases", label = "Best unbox", format = "cash" },
	{ id = "bestAssetId", group = "Cases", label = "Best unbox item", format = "item" },
	{ id = "traits", group = "Items", label = "Traits found", format = "count" },
	{ id = "stacked", group = "Items", label = "Stacked traits found", format = "count" },
	{ id = "trackers", group = "Items", label = "Stat trackers found", format = "count" },
	{ id = "specials", group = "Items", label = "Rare special items", format = "count" },
	{ id = "sold", group = "Selling", label = "Items sold", format = "count" },
	{ id = "soldValue", group = "Selling", label = "Earned from selling", format = "cash" },
	{ id = "autoSold", group = "Selling", label = "Items auto-sold", format = "count" },
	{ id = "upgrades", group = "Games", label = "Upgrades tried", format = "count" },
	{ id = "upgradesWon", group = "Games", label = "Upgrades won", format = "count" },
	{ id = "tradeUps", group = "Games", label = "Trade-ups", format = "count" },
	{ id = "hiloBest", group = "Games", label = "Best Higher or Lower streak", format = "count" },
	{ id = "battles", group = "Games", label = "Case battles", format = "count" },
	{ id = "battlesWon", group = "Games", label = "Case battles won", format = "count" },
	{ id = "cashBets", group = "Cash games", label = "Bets placed", format = "count" },
	{ id = "cashWagered", group = "Cash games", label = "Wagered", format = "cash" },
	{ id = "cashWon", group = "Cash games", label = "Won", format = "cash" },
	{ id = "tradesCompleted", group = "Trading", label = "Trades completed", format = "count" },
	{ id = "passiveEarned", group = "Income", label = "Passive income earned", format = "cash" },
}

function PlayerStats.defaults(): { [string]: number }
	local values = {}
	for _, stat in PlayerStats.list do
		values[stat.id] = 0
	end
	return values
end

return PlayerStats
