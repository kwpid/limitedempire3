-- rare traits rolled on every unbox, independent from the case. each has a chance, value multiplier and visuals.
-- api: Traits.list (rarest last), Traits.get(id) -> trait?, Traits.roll(rng, luck?) -> trait id or nil. luck boosts
-- every trait and boosts rarer ones a bit harder, total trait chance tops out at 95%.
-- Traits.multiplier(id?) -> number, Traits.expectedMultiplier() -> number
-- visuals are read by the shared ItemEffects module, colors by the ui.
--
-- stacking: an item can have up to MAX_TRAITS traits. after the first trait lands, every other trait rolls
-- SECOND_TRAIT_ODDS of its base chance (luck ignored, rarest first) for a second one, so doubles are rarer than
-- both odds together (about 1 in 6,000 unboxes get two, shiny + frozen ~1 in 15,000, rainbow + void ~1 in 60
-- million). stacked traits add instead of multiplying: the best trait counts in full and every other one adds
-- STACK_SHARE of its bonus (glitched + void = 40 + 7 = x47).
-- Traits.rollAll(rng, luck?) -> { trait id } best first (0 to MAX_TRAITS), Traits.of(item) -> { trait id } best
-- first, Traits.combinedMultiplier(ids) -> number, Traits.label(ids) -> "Void + Glitched" or nil,
-- Traits.stackBonus(id) -> what a trait adds when it is not the best one,
-- Traits.fullName(ids, name) -> "Void Glitched Domino Crown"

export type Trait = {
	id: string,
	name: string,
	chance: number,
	multiplier: number,
	announce: boolean,
	color: ColorSequence,
	uiColor: Color3,
	light: boolean,
	particleRate: number,
	meshTint: Vector3?,
}

local function rainbow(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 110)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(140, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
	})
end

local LIST: { Trait } = {
	{
		id = "shiny",
		name = "Shiny",
		chance = 1 / 50,
		multiplier = 1.5,
		announce = false,
		color = ColorSequence.new(Color3.fromRGB(255, 252, 220)),
		uiColor = Color3.fromRGB(255, 246, 190),
		light = false,
		particleRate = 4,
	},
	{
		id = "frozen",
		name = "Frozen",
		chance = 1 / 120,
		multiplier = 2,
		announce = false,
		color = ColorSequence.new(Color3.fromRGB(210, 245, 255), Color3.fromRGB(110, 190, 255)),
		uiColor = Color3.fromRGB(150, 220, 255),
		light = false,
		particleRate = 5,
		meshTint = Vector3.new(0.75, 0.95, 1.3),
	},
	{
		id = "golden",
		name = "Golden",
		chance = 1 / 250,
		multiplier = 3,
		announce = false,
		color = ColorSequence.new(Color3.fromRGB(255, 200, 60)),
		uiColor = Color3.fromRGB(255, 200, 60),
		light = true,
		particleRate = 6,
		meshTint = Vector3.new(1.4, 1.1, 0.35),
	},
	{
		id = "neon",
		name = "Neon",
		chance = 1 / 500,
		multiplier = 4,
		announce = false,
		color = ColorSequence.new(Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255)),
		uiColor = Color3.fromRGB(255, 70, 210),
		light = true,
		particleRate = 8,
	},
	{
		id = "rainbow",
		name = "Rainbow",
		chance = 1 / 1_000,
		multiplier = 6,
		announce = true,
		color = rainbow(),
		uiColor = Color3.fromRGB(255, 120, 220),
		light = true,
		particleRate = 10,
	},
	{
		id = "inferno",
		name = "Inferno",
		chance = 1 / 2_500,
		multiplier = 10,
		announce = true,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 110, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 20, 10)),
		}),
		uiColor = Color3.fromRGB(255, 110, 30),
		light = true,
		particleRate = 12,
		meshTint = Vector3.new(1.3, 0.6, 0.3),
	},
	{
		id = "glitched",
		name = "Glitched",
		chance = 1 / 5_000,
		multiplier = 15,
		announce = true,
		color = ColorSequence.new(Color3.fromRGB(0, 255, 170), Color3.fromRGB(255, 0, 90)),
		uiColor = Color3.fromRGB(0, 255, 170),
		light = true,
		particleRate = 14,
	},
	{
		id = "celestial",
		name = "Celestial",
		chance = 1 / 12_000,
		multiplier = 25,
		announce = true,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 225, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 160, 255)),
		}),
		uiColor = Color3.fromRGB(255, 230, 160),
		light = true,
		particleRate = 16,
	},
	{
		id = "void",
		name = "Void",
		chance = 1 / 25_000,
		multiplier = 40,
		announce = true,
		color = ColorSequence.new(Color3.fromRGB(20, 0, 40), Color3.fromRGB(150, 60, 255)),
		uiColor = Color3.fromRGB(150, 60, 255),
		light = true,
		particleRate = 18,
		meshTint = Vector3.new(0.3, 0.15, 0.45),
	},
	{
		id = "singularity",
		name = "Singularity",
		chance = 1 / 250_000,
		multiplier = 150,
		announce = true,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 150, 60)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 40, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
		}),
		uiColor = Color3.fromRGB(235, 225, 255),
		light = true,
		particleRate = 26,
		meshTint = Vector3.new(0.06, 0.05, 0.1),
	},
}

local byId: { [string]: Trait } = {}
for _, trait in LIST do
	byId[trait.id] = trait
end

local MAX_TRAIT_TOTAL = 0.95
local RARITY_TILT = 0.15
local MAX_TRAITS = 2
local STACK_SHARE = 0.5
local SECOND_TRAIT_ODDS = 0.2

local Traits = {}
Traits.list = LIST

function Traits.get(id: string?): Trait?
	return id and byId[id] or nil
end

function Traits.roll(rng: Random, luck: number?): string?
	local logBoost = math.log(if luck and luck > 1 then math.min(luck, 1e300) else 1)
	local logs = table.create(#LIST)
	local highest = -math.huge
	for i, trait in LIST do
		logs[i] = math.log(trait.chance) + logBoost * (1 + (i - 1) * RARITY_TILT)
		highest = math.max(highest, logs[i])
	end
	local relativeTotal = 0
	for _, value in logs do
		relativeTotal += math.exp(value - highest)
	end
	local logTotal = highest + math.log(relativeTotal)
	local capped = logTotal > math.log(MAX_TRAIT_TOTAL)

	local r = rng:NextNumber()
	local cumulative = 0
	for i = #LIST, 1, -1 do
		cumulative += if capped
			then MAX_TRAIT_TOTAL * math.exp(logs[i] - highest) / relativeTotal
			else math.exp(logs[i])
		if r < cumulative then
			return LIST[i].id
		end
	end
	return nil
end

function Traits.multiplier(id: string?): number
	local trait = Traits.get(id)
	return trait and trait.multiplier or 1
end

function Traits.stackBonus(id: string?): number
	return (Traits.multiplier(id) - 1) * STACK_SHARE
end

-- best (highest multiplier) first, unknown and duplicate ids dropped, capped at MAX_TRAITS
local function sorted(ids: { string? }): { string }
	local list, seen = {}, {}
	for _, id in ids do
		if id and byId[id] and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return byId[a].multiplier > byId[b].multiplier
	end)
	while #list > MAX_TRAITS do
		table.remove(list)
	end
	return list
end

function Traits.rollAll(rng: Random, luck: number?): { string }
	local first = Traits.roll(rng, luck)
	if not first then
		return {}
	end
	local ids = { first }
	for i = #LIST, 1, -1 do
		if #ids >= MAX_TRAITS then
			break
		end
		local trait = LIST[i]
		if trait.id ~= first and rng:NextNumber() < trait.chance * SECOND_TRAIT_ODDS then
			table.insert(ids, trait.id)
		end
	end
	return sorted(ids)
end

-- items saved before stacking only have `trait`
function Traits.of(item: { trait: string?, traits: { string }? }): { string }
	return sorted(item.traits or { item.trait })
end

function Traits.combinedMultiplier(ids: { string }): number
	local list = sorted(ids)
	if #list == 0 then
		return 1
	end
	local total = Traits.multiplier(list[1])
	for i = 2, #list do
		total += Traits.stackBonus(list[i])
	end
	return total
end

function Traits.label(ids: { string }): string?
	local names = {}
	for _, id in sorted(ids) do
		table.insert(names, byId[id].name)
	end
	return if #names > 0 then table.concat(names, " + ") else nil
end

function Traits.fullName(ids: { string }, name: string): string
	local parts = {}
	for _, id in sorted(ids) do
		table.insert(parts, byId[id].name)
	end
	table.insert(parts, name)
	return table.concat(parts, " ")
end

-- average trait multiplier of a fresh unbox (no luck), including the chance of a second trait
local expected = 1
for i, first in LIST do
	expected += first.chance * (first.multiplier - 1)
	local noneRarer = 1
	for j = #LIST, 1, -1 do
		if j ~= i then
			local second = LIST[j]
			local chance = noneRarer * second.chance * SECOND_TRAIT_ODDS
			expected += first.chance * chance * (Traits.combinedMultiplier({ first.id, second.id }) - first.multiplier)
			noneRarer *= 1 - second.chance * SECOND_TRAIT_ODDS
		end
	end
end

function Traits.expectedMultiplier(): number
	return expected
end

return Traits
