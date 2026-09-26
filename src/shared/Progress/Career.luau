-- career level: xp that never resets. each level needs STEP_XP more than the one before it (level 1 -> 2 needs
-- BASE_XP). XP lists what gives xp, MILESTONES what reaching a level unlocks (titles in Shared.Titles, name styles in
-- Shared.Visuals.NameStyles, both unlocked through CosmeticService).
-- api: Career.xpToNext(level) -> number, Career.fromXp(xp) -> (level, xpIntoLevel, xpForLevel),
-- Career.itemXp(item) -> number (xp for unboxing that item, cases add XP.case on top), Career.milestone(level) -> table?

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)

local Career = {}

Career.BASE_XP = 60
Career.STEP_XP = 30
Career.MAX_LEVEL = 500

Career.XP = {
	case = 1,
	tier = { epic = 5, legendary = 15, mythic = 40, exotic = 120, divine = 500 },
	trait = 5,
	stacked = 60,
	tracker = 10,
	upgrade = 2,
	upgradeWin = 6,
	tradeUp = 6,
	hiloCorrect = 1,
	battle = 3,
	battleWin = 8,
	dailyLogin = 20,
}

-- level -> what it unlocks. titles below 30 are grey, 30 and up white (see Shared.Titles)
Career.MILESTONES = {
	[5] = { title = "rookie" },
	[10] = { title = "regular" },
	[15] = { title = "collector" },
	[20] = { title = "hoarder" },
	[25] = { title = "veteran", nameStyle = "steel" },
	[30] = { title = "tycoon" },
	[40] = { title = "mogul" },
	[50] = { title = "elite", nameStyle = "emerald" },
	[75] = { title = "master", nameStyle = "crimson" },
	[100] = { title = "grandmaster", nameStyle = "prismatic" },
}

function Career.xpToNext(level: number): number
	return Career.BASE_XP + Career.STEP_XP * (level - 1)
end

function Career.fromXp(xp: number): (number, number, number)
	local level = 1
	local left = math.max(xp, 0)
	while level < Career.MAX_LEVEL do
		local need = Career.xpToNext(level)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return level, 0, 0
end

function Career.itemXp(item): number
	local xp = Career.XP.tier[ItemRegistry.tier(item.assetId).id] or 0
	local traits = #Traits.of(item)
	if traits > 0 then
		xp += Career.XP.trait
	end
	if traits > 1 then
		xp += Career.XP.stacked
	end
	if item.tracker then
		xp += Career.XP.tracker
	end
	return xp
end

function Career.milestone(level: number)
	return Career.MILESTONES[level]
end

return Career
