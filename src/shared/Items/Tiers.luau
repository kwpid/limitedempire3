-- rarity tiers, picked from an item's base value so an item is the same tier in every case.
-- each tier above legendary is roughly 4-5x the one below and holds fewer items, divine is the ~13 best items.
-- gradient (optional) is an animated shimmer the ui puts on the tier's bars and labels.
-- api: Tiers.list (ordered low to high), Tiers.fromValue(value) -> tier, Tiers.get(id) -> tier

export type Tier = {
	id: string,
	name: string,
	minValue: number,
	color: Color3,
	rank: number,
	gradient: ColorSequence?,
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

local byId = {}
for _, tier in LIST do
	byId[tier.id] = tier
end

local Tiers = {}
Tiers.list = LIST

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
