-- quests. every quest counts one metric up to a goal; the server (ProgressService) feeds metrics from what players
-- do and pays the reward the moment a quest is done.
--   daily: DAILY_PER_DIFFICULTY quests of each difficulty from the daily pool, new ones every utc day
--   weekly: one of each difficulty from the weekly pool, new ones every utc week (weeks start on thursday, day 0)
--   achievements: permanent, count lifetime totals, done once. some unlock a title.
-- metrics (what ProgressService tracks): cases, premiumCases (cost 15k+), epicPlus, legendaryPlus, mythicPlus,
-- exoticPlus, divine, traits, stacked, trackers, sold, unboxedValue, upgrades, upgradeWins, tradeUps,
-- hiloStreak (best streak, counts as a max), battles, battleWins, logins
-- rewards: { xp, sp, cash, title? }
-- api: Quests.daily, Quests.weekly, Quests.achievements (lists), Quests.get(id), Quests.pick(pool, seed) -> { id },
-- Quests.isMax(metric) -> boolean, Quests.week(day) -> number

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

Quests.daily = {
	quest("d_open10", "Open 10 cases", "cases", 10, "easy", DAILY_REWARD.easy),
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

	quest("d_legendary1", "Unbox a Legendary or better item", "legendaryPlus", 1, "hard", DAILY_REWARD.hard),
	quest("d_open100", "Open 100 cases", "cases", 100, "hard", DAILY_REWARD.hard),
	quest("d_trait1", "Unbox an item with a trait", "traits", 1, "hard", DAILY_REWARD.hard),
	quest("d_upgradewin3", "Win 3 upgrades", "upgradeWins", 3, "hard", DAILY_REWARD.hard),
	quest("d_hilo8", "Get an 8 streak in Higher or Lower", "hiloStreak", 8, "hard", DAILY_REWARD.hard),
	quest("d_battlewin3", "Win 3 case battles", "battleWins", 3, "hard", DAILY_REWARD.hard),
} :: { Quest }

Quests.weekly = {
	quest("w_open300", "Open 300 cases", "cases", 300, "easy", WEEKLY_REWARD.easy),
	quest("w_sell100", "Sell 100 items", "sold", 100, "easy", WEEKLY_REWARD.easy),
	quest("w_battles10", "Play 10 case battles", "battles", 10, "easy", WEEKLY_REWARD.easy),

	quest("w_legendary5", "Unbox 5 Legendary or better items", "legendaryPlus", 5, "medium", WEEKLY_REWARD.medium),
	quest("w_value5m", "Unbox T$5M worth of items", "unboxedValue", 5_000_000, "medium", WEEKLY_REWARD.medium),
	quest("w_traits3", "Unbox 3 items with traits", "traits", 3, "medium", WEEKLY_REWARD.medium),
	quest("w_tradeups10", "Complete 10 trade-ups", "tradeUps", 10, "medium", WEEKLY_REWARD.medium),

	quest("w_mythic1", "Unbox a Mythic or better item", "mythicPlus", 1, "hard", WEEKLY_REWARD.hard),
	quest("w_battlewins10", "Win 10 case battles", "battleWins", 10, "hard", WEEKLY_REWARD.hard),
	quest("w_upgradewins15", "Win 15 upgrades", "upgradeWins", 15, "hard", WEEKLY_REWARD.hard),
	quest("w_open1500", "Open 1,500 cases", "cases", 1_500, "hard", WEEKLY_REWARD.hard),
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
for _, list in { Quests.daily, Quests.weekly, Quests.achievements } do
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

-- one quest of each difficulty from the pool, the same for a given seed (day or week + user id)
function Quests.pick(pool: { Quest }, seed: number): { string }
	local rng = Random.new(seed)
	local picked = {}
	for _, difficulty in Quests.DIFFICULTIES do
		local options = {}
		for _, entry in pool do
			if entry.difficulty == difficulty then
				table.insert(options, entry.id)
			end
		end
		if #options > 0 then
			table.insert(picked, options[rng:NextInteger(1, #options)])
		end
	end
	return picked
end

return Quests
