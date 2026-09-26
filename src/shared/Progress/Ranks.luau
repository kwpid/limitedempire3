-- season ranks from Season Points. every tier but Legend has three divisions (I, II, III) splitting the SP range
-- up to the next tier evenly.
-- api: Ranks.tiers (low to high), Ranks.fromSp(sp) -> Rank { tier, division?, name, color, order },
-- Ranks.bounds(sp) -> (sp where the current rank starts, sp where the next one starts or nil at Legend)

export type Tier = { id: string, name: string, min: number, color: Color3, divisions: boolean }
export type Rank = { tier: Tier, division: number?, name: string, color: Color3, order: number }

local Ranks = {}

Ranks.tiers = {
	{ id = "bronze", name = "Bronze", min = 0, color = Color3.fromRGB(205, 127, 70), divisions = true },
	{ id = "silver", name = "Silver", min = 1_000, color = Color3.fromRGB(190, 200, 212), divisions = true },
	{ id = "gold", name = "Gold", min = 3_500, color = Color3.fromRGB(255, 196, 46), divisions = true },
	{ id = "diamond", name = "Diamond", min = 10_000, color = Color3.fromRGB(110, 210, 255), divisions = true },
	{ id = "champion", name = "Champion", min = 25_000, color = Color3.fromRGB(200, 90, 255), divisions = true },
	{ id = "legend", name = "Legend", min = 50_000, color = Color3.fromRGB(255, 90, 90), divisions = false },
} :: { Tier }

local ROMAN = { "I", "II", "III" }

function Ranks.fromSp(sp: number): Rank
	local value = math.max(sp, 0)
	for index = #Ranks.tiers, 1, -1 do
		local tier = Ranks.tiers[index]
		if value >= tier.min then
			if not tier.divisions then
				return { tier = tier, division = nil, name = tier.name, color = tier.color, order = index * 3 }
			end
			local nextMin = Ranks.tiers[index + 1].min
			local division = math.clamp(math.floor((value - tier.min) / (nextMin - tier.min) * 3) + 1, 1, 3)
			return {
				tier = tier,
				division = division,
				name = `{tier.name} {ROMAN[division]}`,
				color = tier.color,
				order = (index - 1) * 3 + division,
			}
		end
	end
	local first = Ranks.tiers[1]
	return { tier = first, division = 1, name = `{first.name} I`, color = first.color, order = 1 }
end

function Ranks.bounds(sp: number): (number, number?)
	local rank = Ranks.fromSp(sp)
	local tier = rank.tier
	if not rank.division then
		return tier.min, nil
	end
	local index = table.find(Ranks.tiers, tier) :: number
	local nextMin = Ranks.tiers[index + 1].min
	local step = (nextMin - tier.min) / 3
	return math.ceil(tier.min + step * (rank.division - 1)), math.ceil(tier.min + step * rank.division)
end

return Ranks
