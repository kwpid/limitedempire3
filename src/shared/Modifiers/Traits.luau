-- rare traits rolled on every unbox, independent from the case. each has a chance, value multiplier and visuals.
-- api: Traits.list (rarest last), Traits.get(id) -> trait?, Traits.roll(rng, luck?) -> trait id or nil. luck boosts
-- every trait and boosts rarer ones a bit harder, total trait chance tops out at 95%.
-- Traits.multiplier(id?) -> number, Traits.expectedMultiplier() -> number
-- visuals are read by the server TraitEffects module, colors by the ui.

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
}

local byId: { [string]: Trait } = {}
for _, trait in LIST do
	byId[trait.id] = trait
end

local MAX_TRAIT_TOTAL = 0.95
local RARITY_TILT = 0.15

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

local expected = 1
for _, trait in LIST do
	expected += trait.chance * (trait.multiplier - 1)
end

function Traits.expectedMultiplier(): number
	return expected
end

return Traits
