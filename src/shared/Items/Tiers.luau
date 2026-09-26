-- rarity tiers, picked from an item's base value so an item is the same tier in every case.
-- each tier above legendary is roughly 4-5x the one below and holds fewer items, divine is the ~13 best items.
-- gradient (optional) is an animated shimmer the ui puts on the tier's bars and labels.
-- custom rarities (Tiers.custom) are never picked from value: only custom items that name one with their rarity
-- field (see Items/CustomItems) have them. they sit outside the value ladder, so they are left out of case odds,
-- auto-sell and the admin rarity override. "season1" to "season5" ("Season 1", ...) are for each season's top
-- item from its season case (the Alpha reward keeps "alpha"); add a color to SEASON_COLORS for more seasons.
-- api: Tiers.list (value tiers, ordered low to high), Tiers.custom (custom rarities), Tiers.fromValue(value) -> tier,
-- Tiers.get(id) -> tier (value or custom)

export type Tier = {
	id: string,
	name: string,
	minValue: number,
	color: Color3,
	rank: number,
	gradient: ColorSequence?,
	custom: boolean?,
}

local LIST: { Tier } = {
	{ id = "common", name = "Common", minValue = 0, color = Color3.fromRGB(176, 195, 217), rank = 1 },
	{ id = "uncommon", name = "Uncommon", minValue = 1_500, color = Color3.fromRGB(94, 152, 217), rank = 2 },
	{ id = "rare", name = "Rare", minValue = 6_000, color = Color3.fromRGB(75, 105, 255), rank = 3 },
	{ id = "epic", name = "Epic", minValue = 30_000, color = Color3.fromRGB(136, 71, 255), rank = 4 },
	{ id = "legendary", name = "Legendary", minValue = 200_000, color = Color3.fromRGB(211, 44, 230), rank = 5 },
	{ id = "mythic", name = "Mythic", minValue = 1_000_000, color = Color3.fromRGB(235, 75, 75), rank = 6 },
	{ id = "exotic", name = "Exotic", minValue = 5_000_000, color = Color3.fromRGB(255, 184, 28), rank = 7 },
	{
		id = "divine",
		name = "Divine",
		minValue = 20_000_000,
		color = Color3.fromRGB(255, 255, 255),
		rank = 8,
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 190, 240)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 225, 255)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 245, 190)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
	},
}

-- rank 0 so nothing that compares ranks (reveal sounds) treats them as a value tier
local CUSTOM: { Tier } = {
	{
		id = "alpha",
		name = "Alpha",
		minValue = math.huge,
		color = Color3.fromRGB(255, 196, 46),
		rank = 0,
		custom = true,
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 46)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 196, 46)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 200)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 196, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 196, 46)),
		}),
	},
	{
		id = "dev",
		name = "Dev",
		minValue = math.huge,
		color = Color3.fromRGB(80, 230, 140),
		rank = 0,
		custom = true,
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 230, 140)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 210, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 230, 140)),
		}),
	},
}

-- one custom rarity per season for its season case's top item: "season1" = "Season 1", ...
local SEASON_COLORS = {
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(255, 110, 170),
	Color3.fromRGB(120, 235, 140),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(190, 130, 255),
}
for season, color in SEASON_COLORS do
	table.insert(CUSTOM, {
		id = `season{season}`,
		name = `Season {season}`,
		minValue = math.huge,
		color = color,
		rank = 0,
		custom = true,
		gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.45, color),
			ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.7)),
			ColorSequenceKeypoint.new(0.55, color),
			ColorSequenceKeypoint.new(1, color),
		}),
	})
end

local byId = {}
for _, tier in LIST do
	byId[tier.id] = tier
end
for _, tier in CUSTOM do
	assert(not byId[tier.id], `duplicate tier id "{tier.id}"`)
	byId[tier.id] = tier
end

local Tiers = {}
Tiers.list = LIST
Tiers.custom = CUSTOM

function Tiers.fromValue(value: number): Tier
	for i = #LIST, 1, -1 do
		if value >= LIST[i].minValue then
			return LIST[i]
		end
	end
	return LIST[1]
end

function Tiers.get(id: string): Tier?
	return byId[id]
end

return Tiers
