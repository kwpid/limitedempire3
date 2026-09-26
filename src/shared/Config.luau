-- global tuning values shared by server and client, read with require(ReplicatedStorage.Shared.Config).
-- case price = expected value * (1 + HouseEdge), a case in CaseData can set its own (the starter cases do). SellRate is the fraction of value paid out on sell.
-- any unbox worth AnnounceValue or more gets announced to the whole server.
-- selling always asks for a second click. items worth SellHoldValue or more also make the player wait
-- SellHoldSeconds before the confirm click works.
-- Overhead.ShowOwn shows your own overhead above your character. overheads are WidthStuds wide in the world, so they
-- shrink as you zoom out like any other object. MaxDistance (studs) hides them past that range, math.huge = always visible.
-- StatTracker.Chance is the odds an unboxed item comes with a stat tracker (counts cases opened while the item is
-- equipped), Multiplier is the value bonus for having one. the count itself does not change the value.

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

	StatTracker = {
		Chance = 1 / 60,
		Multiplier = 1.2,
	},

	Trade = {
		MaxItems = 10,
		ExpireDays = 7,
		MaxOutbound = 25,
		MaxInbound = 50,
		KeepHistory = 30,
		ActionCooldown = 0.5,
	},

	Overhead = {
		ShowOwn = true,
		WidthStuds = 6,
		MaxDistance = math.huge,
	},
}

return table.freeze(Config)
