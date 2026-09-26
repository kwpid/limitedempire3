-- global tuning values shared by server and client, read with require(ReplicatedStorage.Shared.Config).
-- case price = expected value * (1 + HouseEdge). SellRate is the fraction of value paid out on sell.
-- any unbox worth AnnounceValue or more gets announced to the whole server.
-- selling always asks for a second click. items worth SellHoldValue or more also make the player wait
-- SellHoldSeconds before the confirm click works.
-- Overhead.ShowOwn shows your own overhead above your character. overheads are a fixed pixel size at any distance,
-- MaxDistance (studs) hides them past that range, math.huge = always visible.

local Config = {
	GameName = "Limited Empire",

	Currency = {
		Name = "Tix",
		Symbol = "T$",
	},

	StartingCash = 30000,
	HouseEdge = 0.12,
	SellRate = 1,

	OpenCooldown = 0.6,
	MaxEquipped = 6,
	MaxSellBatch = 500,

	AnnounceValue = 1_000_000,

	SellHoldValue = 1_000_000,
	SellHoldSeconds = 3,

	Overhead = {
		ShowOwn = true,
		MaxDistance = math.huge,
	},
}

return table.freeze(Config)
