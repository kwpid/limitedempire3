-- quests. every quest counts one metric up to a goal; the server (ProgressService) feeds metrics from what players
-- do and pays the reward the moment a quest is done.
--   hourly: one easy and one medium quest from the hourly pool, new ones every hour
--   daily: PER_DIFFICULTY.daily quests of each difficulty from the daily pool, new ones every utc day
--   weekly: PER_DIFFICULTY.weekly of each difficulty from the weekly pool, new ones every utc week (weeks start on
--     thursday, day 0)
--   achievements: permanent, count lifetime totals, done once. some unlock a title.
-- metrics (what ProgressService tracks): cases, premiumCases (cost 15k+), spent (cash spent on cases), epicPlus,
-- legendaryPlus, mythicPlus, exoticPlus, divine, traits, stacked, trackers, sold, unboxedValue, upgrades, upgradeWins,
-- tradeUps, hiloStreak (best streak, counts as a max), battles, battleWins, logins
-- rewards: { xp, sp, cash, title? }
-- api: Quests.hourly, Quests.daily, Quests.weekly, Quests.achievements (lists), Quests.get(id),
-- Quests.pick(pool, seed, perDifficulty?) -> { id }, Quests.isMax(metric) -> boolean, Quests.week(day) -> number,
-- Quests.hour(now?) -> number

local Quests = {}

export type Quest = {
	id: string,
	name: string,
	metric: string,
	goal: number,
	difficulty: string,
	reward: { xp: number?, sp: number?, cash: number?, title: string? },
}

Quests.DIFFICULTIES = { "easy", "medium", "hard" }
Quests.DIFFICULTY_COLORS = {
	easy = Color3.fromRGB(110, 200, 110),
	medium = Color3.fromRGB(240, 190, 70),
	hard = Color3.fromRGB(235, 90, 90),
	epic = Color3.fromRGB(180, 110, 255),
}

local MAX_METRICS = { hiloStreak = true }

Quests.PER_DIFFICULTY = { hourly = 1, daily = 2, weekly = 2 }

local HOURLY_REWARD = {
	easy = { xp = 15, sp = 5, cash = 1_000 },
	medium = { xp = 35, sp = 12, cash = 3_000 },
}
local DAILY_REWARD = {
	easy = { xp = 40, sp = 15, cash = 2_500 },
	medium = { xp = 100, sp = 40, cash = 7_500 },
	hard = { xp = 250, sp = 100, cash = 20_000 },
}
local WEEKLY_REWARD = {
	easy = { xp = 400, sp = 150, cash = 30_000 },
	medium = { xp = 800, sp = 300, cash = 75_000 },
	hard = { xp = 1_500, sp = 600, cash = 150_000 },
}

local function quest(id: string, name: string, metric: string, goal: number, difficulty: string, reward)
	return { id = id, name = name, metric = metric, goal = goal, difficulty = difficulty, reward = reward }
end

Quests.hourly = {
	quest("h_open5", "Open 5 cases", "cases", 5, "easy", HOURLY_REWARD.easy),
	quest("h_open10", "Open 10 cases", "cases", 10, "easy", HOURLY_REWARD.easy),
	quest("h_sell5", "Sell 5 items", "sold", 5, "easy", HOURLY_REWARD.easy),
	quest("h_upgrade1", "Try an upgrade", "upgrades", 1, "easy", HOURLY_REWARD.easy),
	quest("h_hilo2", "Get a 2 streak in Higher or Lower", "hiloStreak", 2, "easy", HOURLY_REWARD.easy),
	quest("h_battle1", "Play a case battle", "battles", 1, "easy", HOURLY_REWARD.easy),
	quest("h_spend25k", "Spend T$25K on cases", "spent", 25_000, "easy", HOURLY_REWARD.easy),

	quest("h_open25", "Open 25 cases", "cases", 25, "medium", HOURLY_REWARD.medium),
	quest("h_epic1", "Unbox an Epic or better item", "epicPlus", 1, "medium", HOURLY_REWARD.medium),
	quest("h_tradeup1", "Complete a trade-up", "tradeUps", 1, "medium", HOURLY_REWARD.medium),
	quest("h_upgradewin1", "Win an upgrade", "upgradeWins", 1, "medium", HOURLY_REWARD.medium),
	quest("h_hilo4", "Get a 4 streak in Higher or Lower", "hiloStreak", 4, "medium", HOURLY_REWARD.medium),
	quest("h_value100k", "Unbox T$100K worth of items", "unboxedValue", 100_000, "medium", HOURLY_REWARD.medium),
	quest("h_battlewin1", "Win a case battle", "battleWins", 1, "medium", HOURLY_REWARD.medium),
	quest("h_premium3", "Open 3 cases that cost T$15K or more", "premiumCases", 3, "medium", HOURLY_REWARD.medium),
} :: { Quest }

Quests.daily = {
	quest("d_open10", "Open 10 cases", "cases", 10, "easy", DAILY_REWARD.easy),
	quest("d_open25", "Open 25 cases", "cases", 25, "easy", DAILY_REWARD.easy),
	quest("d_epic1", "Unbox an Epic or better item", "epicPlus", 1, "easy", DAILY_REWARD.easy),
	quest("d_battles3", "Play 3 case battles", "battles", 3, "easy", DAILY_REWARD.easy),
	quest("d_spend75k", "Spend T$75K on cases", "spent", 75_000, "easy", DAILY_REWARD.easy),
	quest("d_upgradewin1", "Win an upgrade", "upgradeWins", 1, "easy", DAILY_REWARD.easy),
	quest("d_sell10", "Sell 10 items", "sold", 10, "easy", DAILY_REWARD.easy),
	quest("d_battle1", "Play a case battle", "battles", 1, "easy", DAILY_REWARD.easy),
	quest("d_hilo3", "Get a 3 streak in Higher or Lower", "hiloStreak", 3, "easy", DAILY_REWARD.easy),
	quest("d_upgrade3", "Try 3 upgrades", "upgrades", 3, "easy", DAILY_REWARD.easy),

	quest("d_open40", "Open 40 cases", "cases", 40, "medium", DAILY_REWARD.medium),
	quest("d_epic3", "Unbox 3 Epic or better items", "epicPlus", 3, "medium", DAILY_REWARD.medium),
	quest("d_value250k", "Unbox T$250K worth of items", "unboxedValue", 250_000, "medium", DAILY_REWARD.medium),
	quest("d_tradeup1", "Complete a trade-up", "tradeUps", 1, "medium", DAILY_REWARD.medium),
	quest("d_battlewin1", "Win a case battle", "battleWins", 1, "medium", DAILY_REWARD.medium),
	quest("d_premium10", "Open 10 cases that cost T$15K or more", "premiumCases", 10, "medium", DAILY_REWARD.medium),
	quest("d_sell40", "Sell 40 items", "sold", 40, "medium", DAILY_REWARD.medium),
	quest("d_hilo5", "Get a 5 streak in Higher or Lower", "hiloStreak", 5, "medium", DAILY_REWARD.medium),
	quest("d_tradeups3", "Complete 3 trade-ups", "tradeUps", 3, "medium", DAILY_REWARD.medium),
	quest("d_spend300k", "Spend T$300K on cases", "spent", 300_000, "medium", DAILY_REWARD.medium),
	quest("d_upgrades10", "Try 10 upgrades", "upgrades", 10, "medium", DAILY_REWARD.medium),
	quest("d_battles8", "Play 8 case battles", "battles", 8, "medium", DAILY_REWARD.medium),

	quest("d_legendary1", "Unbox a Legendary or better item", "legendaryPlus", 1, "hard", DAILY_REWARD.hard),
	quest("d_open100", "Open 100 cases", "cases", 100, "hard", DAILY_REWARD.hard),
	quest("d_trait1", "Unbox an item with a trait", "traits", 1, "hard", DAILY_REWARD.hard),
	quest("d_upgradewin3", "Win 3 upgrades", "upgradeWins", 3, "hard", DAILY_REWARD.hard),
	quest("d_hilo8", "Get an 8 streak in Higher or Lower", "hiloStreak", 8, "hard", DAILY_REWARD.hard),
	quest("d_battlewin3", "Win 3 case battles", "battleWins", 3, "hard", DAILY_REWARD.hard),
	quest("d_value1m", "Unbox T$1M worth of items", "unboxedValue", 1_000_000, "hard", DAILY_REWARD.hard),
	quest("d_premium40", "Open 40 cases that cost T$15K or more", "premiumCases", 40, "hard", DAILY_REWARD.hard),
	quest("d_tradeups8", "Complete 8 trade-ups", "tradeUps", 8, "hard", DAILY_REWARD.hard),
	quest("d_open200", "Open 200 cases", "cases", 200, "hard", DAILY_REWARD.hard),
	quest("d_epic10", "Unbox 10 Epic or better items", "epicPlus", 10, "hard", DAILY_REWARD.hard),
	quest("d_spend1m", "Spend T$1M on cases", "spent", 1_000_000, "hard", DAILY_REWARD.hard),
} :: { Quest }

Quests.weekly = {
	quest("w_open300", "Open 300 cases", "cases", 300, "easy", WEEKLY_REWARD.easy),
	quest("w_sell100", "Sell 100 items", "sold", 100, "easy", WEEKLY_REWARD.easy),
	quest("w_battles10", "Play 10 case battles", "battles", 10, "easy", WEEKLY_REWARD.easy),
	quest("w_upgrades25", "Try 25 upgrades", "upgrades", 25, "easy", WEEKLY_REWARD.easy),
	quest("w_hilo6", "Get a 6 streak in Higher or Lower", "hiloStreak", 6, "easy", WEEKLY_REWARD.easy),
	quest("w_spend1m", "Spend T$1M on cases", "spent", 1_000_000, "easy", WEEKLY_REWARD.easy),
	quest("w_epic10", "Unbox 10 Epic or better items", "epicPlus", 10, "easy", WEEKLY_REWARD.easy),
	quest("w_tradeups3", "Complete 3 trade-ups", "tradeUps", 3, "easy", WEEKLY_REWARD.easy),

	quest("w_legendary5", "Unbox 5 Legendary or better items", "legendaryPlus", 5, "medium", WEEKLY_REWARD.medium),
	quest("w_value5m", "Unbox T$5M worth of items", "unboxedValue", 5_000_000, "medium", WEEKLY_REWARD.medium),
	quest("w_traits3", "Unbox 3 items with traits", "traits", 3, "medium", WEEKLY_REWARD.medium),
	quest("w_tradeups10", "Complete 10 trade-ups", "tradeUps", 10, "medium", WEEKLY_REWARD.medium),
	quest("w_open700", "Open 700 cases", "cases", 700, "medium", WEEKLY_REWARD.medium),
	quest("w_epic30", "Unbox 30 Epic or better items", "epicPlus", 30, "medium", WEEKLY_REWARD.medium),
	quest("w_hilo10", "Get a 10 streak in Higher or Lower", "hiloStreak", 10, "medium", WEEKLY_REWARD.medium),
	quest("w_battlewins5", "Win 5 case battles", "battleWins", 5, "medium", WEEKLY_REWARD.medium),
	quest(
		"w_premium100",
		"Open 100 cases that cost T$15K or more",
		"premiumCases",
		100,
		"medium",
		WEEKLY_REWARD.medium
	),
	quest("w_sell300", "Sell 300 items", "sold", 300, "medium", WEEKLY_REWARD.medium),

	quest("w_mythic1", "Unbox a Mythic or better item", "mythicPlus", 1, "hard", WEEKLY_REWARD.hard),
	quest("w_battlewins10", "Win 10 case battles", "battleWins", 10, "hard", WEEKLY_REWARD.hard),
	quest("w_upgradewins15", "Win 15 upgrades", "upgradeWins", 15, "hard", WEEKLY_REWARD.hard),
	quest("w_open1500", "Open 1,500 cases", "cases", 1_500, "hard", WEEKLY_REWARD.hard),
	quest("w_value50m", "Unbox T$50M worth of items", "unboxedValue", 50_000_000, "hard", WEEKLY_REWARD.hard),
	quest("w_tradeups30", "Complete 30 trade-ups", "tradeUps", 30, "hard", WEEKLY_REWARD.hard),
	quest("w_trackers2", "Unbox 2 stat tracker items", "trackers", 2, "hard", WEEKLY_REWARD.hard),
	quest("w_legendary15", "Unbox 15 Legendary or better items", "legendaryPlus", 15, "hard", WEEKLY_REWARD.hard),
	quest("w_spend10m", "Spend T$10M on cases", "spent", 10_000_000, "hard", WEEKLY_REWARD.hard),
	quest("w_hilo15", "Get a 15 streak in Higher or Lower", "hiloStreak", 15, "hard", WEEKLY_REWARD.hard),
} :: { Quest }

Quests.achievements = {
	quest("a_open100", "Open 100 cases", "cases", 100, "easy", { xp = 200, sp = 50, cash = 10_000 }),
	quest(
		"a_open1k",
		"Open 1,000 cases",
		"cases",
		1_000,
		"medium",
		{ xp = 1_000, sp = 200, cash = 50_000, title = "unboxer" }
	),
	quest(
		"a_open10k",
		"Open 10,000 cases",
		"cases",
		10_000,
		"hard",
		{ xp = 5_000, sp = 800, cash = 250_000, title = "case_addict" }
	),
	quest(
		"a_open100k",
		"Open 100,000 cases",
		"cases",
		100_000,
		"epic",
		{ xp = 25_000, sp = 3_000, cash = 2_000_000, title = "no_life" }
	),
	quest("a_epic", "Unbox your first Epic", "epicPlus", 1, "easy", { xp = 50, sp = 20, cash = 5_000 }),
	quest(
		"a_legendary",
		"Unbox your first Legendary",
		"legendaryPlus",
		1,
		"medium",
		{ xp = 250, sp = 80, cash = 25_000 }
	),
	quest("a_mythic", "Unbox your first Mythic", "mythicPlus", 1, "hard", { xp = 1_000, sp = 300, cash = 100_000 }),
	quest("a_exotic", "Unbox your first Exotic", "exoticPlus", 1, "hard", { xp = 3_000, sp = 800, cash = 500_000 }),
	quest(
		"a_divine",
		"Unbox a Divine item",
		"divine",
		1,
		"epic",
		{ xp = 10_000, sp = 2_500, cash = 2_500_000, title = "chosen" }
	),
	quest("a_trait", "Unbox your first trait", "traits", 1, "easy", { xp = 100, sp = 40, cash = 10_000 }),
	quest("a_traits25", "Unbox 25 traits", "traits", 25, "hard", { xp = 2_000, sp = 500, cash = 200_000 }),
	quest(
		"a_stacked",
		"Unbox a stacked trait",
		"stacked",
		1,
		"epic",
		{ xp = 5_000, sp = 1_500, cash = 1_000_000, title = "two_of_a_kind" }
	),
	quest("a_tracker", "Unbox a stat tracker", "trackers", 1, "medium", { xp = 300, sp = 100, cash = 25_000 }),
	quest("a_battlewins10", "Win 10 case battles", "battleWins", 10, "medium", { xp = 500, sp = 150, cash = 50_000 }),
	quest(
		"a_battlewins100",
		"Win 100 case battles",
		"battleWins",
		100,
		"hard",
		{ xp = 4_000, sp = 1_000, cash = 400_000, title = "gladiator" }
	),
	quest("a_upgradewins10", "Win 10 upgrades", "upgradeWins", 10, "medium", { xp = 400, sp = 120, cash = 40_000 }),
	quest("a_upgradewins100", "Win 100 upgrades", "upgradeWins", 100, "hard", { xp = 3_000, sp = 800, cash = 300_000 }),
	quest("a_tradeups50", "Complete 50 trade-ups", "tradeUps", 50, "hard", { xp = 2_000, sp = 500, cash = 150_000 }),
	quest(
		"a_hilo15",
		"Get a 15 streak in Higher or Lower",
		"hiloStreak",
		15,
		"hard",
		{ xp = 1_500, sp = 400, cash = 100_000, title = "know_it_all" }
	),
	quest(
		"a_value1m",
		"Unbox T$1M worth of items",
		"unboxedValue",
		1_000_000,
		"easy",
		{ xp = 300, sp = 80, cash = 25_000 }
	),
	quest(
		"a_value100m",
		"Unbox T$100M worth of items",
		"unboxedValue",
		100_000_000,
		"hard",
		{ xp = 3_000, sp = 800, cash = 500_000 }
	),
	quest(
		"a_value1b",
		"Unbox T$1B worth of items",
		"unboxedValue",
		1_000_000_000,
		"epic",
		{ xp = 15_000, sp = 3_000, cash = 5_000_000, title = "billionaire" }
	),
	quest("a_logins7", "Log in on 7 different days", "logins", 7, "easy", { xp = 300, sp = 100, cash = 25_000 }),
	quest(
		"a_logins30",
		"Log in on 30 different days",
		"logins",
		30,
		"medium",
		{ xp = 1_500, sp = 400, cash = 100_000, title = "regular_face" }
	),
} :: { Quest }

local byId: { [string]: Quest } = {}
for _, list in { Quests.hourly, Quests.daily, Quests.weekly, Quests.achievements } do
	for _, entry in list do
		assert(not byId[entry.id], `duplicate quest id "{entry.id}"`)
		byId[entry.id] = entry
	end
end

function Quests.get(id: string): Quest?
	return byId[id]
end

function Quests.isMax(metric: string): boolean
	return MAX_METRICS[metric] == true
end

function Quests.week(day: number): number
	return math.floor(day / 7)
end

function Quests.hour(now: number?): number
	return math.floor((now or os.time()) / 3600)
end

-- perDifficulty (default 1) different quests of each difficulty from the pool, the same for a given seed (hour, day
-- or week + user id). two quests on the same metric are never picked together
function Quests.pick(pool: { Quest }, seed: number, perDifficulty: number?): { string }
	local rng = Random.new(seed)
	local picked = {}
	local usedMetrics = {}
	for _, difficulty in Quests.DIFFICULTIES do
		local options = {}
		for _, entry in pool do
			if entry.difficulty == difficulty then
				table.insert(options, entry)
			end
		end
		local count = 0
		while count < (perDifficulty or 1) and #options > 0 do
			local entry = table.remove(options, rng:NextInteger(1, #options))
			if not usedMetrics[entry.metric] then
				usedMetrics[entry.metric] = true
				table.insert(picked, entry.id)
				count += 1
			end
		end
	end
	return picked
end

return Quests
