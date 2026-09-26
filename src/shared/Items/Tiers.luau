-- rarity tiers, picked from an item's base value so an item is the same tier in every case.
-- api: Tiers.list (ordered low to high), Tiers.fromValue(value) -> tier, Tiers.get(id) -> tier

export type Tier = {
	id: string,
	name: string,
	minValue: number,
	color: Color3,
	rank: number,
}

local LIST: { Tier } = {
	{ id = "common", name = "Common", minValue = 0, color = Color3.fromRGB(176, 195, 217), rank = 1 },
	{ id = "uncommon", name = "Uncommon", minValue = 1_500, color = Color3.fromRGB(94, 152, 217), rank = 2 },
	{ id = "rare", name = "Rare", minValue = 6_000, color = Color3.fromRGB(75, 105, 255), rank = 3 },
	{ id = "epic", name = "Epic", minValue = 30_000, color = Color3.fromRGB(136, 71, 255), rank = 4 },
	{ id = "legendary", name = "Legendary", minValue = 200_000, color = Color3.fromRGB(211, 44, 230), rank = 5 },
	{ id = "mythic", name = "Mythic", minValue = 2_000_000, color = Color3.fromRGB(235, 75, 75), rank = 6 },
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
