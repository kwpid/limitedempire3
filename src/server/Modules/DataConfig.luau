-- datastore names and the player data template, in one place.
-- hard reset for everyone: bump DATA_VERSION. every store name includes it, so all players start fresh and all
-- serial counters restart at #1. old data is left untouched in the old stores (bump back to restore it).
-- per player resets for testing live in the admin panel ("wipe my data", "wipe my data + reset serials").
--
-- api: DataConfig.PlayerStore, DataConfig.SerialStore (store names), DataConfig.template() -> fresh player data

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)

local DATA_VERSION = 2

local DataConfig = {
	Version = DATA_VERSION,
	PlayerStore = `PlayerData_v{DATA_VERSION}`,
	SerialStore = `Serials_v{DATA_VERSION}`,
}

function DataConfig.template()
	return {
		cash = Config.StartingCash,
		inventory = {},
		equipped = {},
		pinned = {},
		daily = { day = 0, hiloEarned = 0 },
		career = { xp = 0 },
		season = { id = 0, sp = 0, peak = 0, lastActiveDay = 0, lastLoginDay = 0, history = {} },
		quests = { hourly = {}, daily = {}, weekly = {}, done = {} },
		metrics = {},
		settings = {},
		cosmetics = {
			title = { equipped = "none", unlocked = {} },
			nameStyle = { equipped = "default", unlocked = {} },
		},
		stats = PlayerStats.defaults(),
		trades = {},
		tradeOutbox = {},
		boosts = {},
		codes = {},
		login = { streak = 0, lastClaimDay = 0 },
	}
end

return DataConfig
