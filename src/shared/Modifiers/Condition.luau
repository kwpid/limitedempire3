-- item condition, driven by a float from 0 to 1 (lower is better). bands give the name, color and avatar tint.
-- value follows the float smoothly (Condition.multiplier): anywhere in Clean is exactly the base value, every bit
-- better than Clean adds value (up to x1.6 at a perfect 0.000000) and every bit worse slowly takes some away (down
-- to x0.6 at 1.0). the band multipliers below are only rough labels for that curve.
-- api: Condition.list, Condition.fromFloat(f) -> band, Condition.multiplier(f) -> number,
-- Condition.rollFloat(rng, luck?) -> number,
-- Condition.expectedMultiplier() -> average multiplier across all floats (used for case pricing)

export type Band = {
	id: string,
	name: string,
	min: number,
	max: number,
	multiplier: number,
	color: Color3,
	tint: Color3,
}

local LIST: { Band } = {
	{ id = "mint", name = "Mint", min = 0, max = 0.03, multiplier = 1.5, color = Color3.fromRGB(120, 255, 214), tint = Color3.new(1, 1, 1) },
	{ id = "pristine", name = "Pristine", min = 0.03, max = 0.12, multiplier = 1.2, color = Color3.fromRGB(140, 214, 255), tint = Color3.new(1, 1, 1) },
	{ id = "clean", name = "Clean", min = 0.12, max = 0.35, multiplier = 1, color = Color3.fromRGB(220, 224, 232), tint = Color3.fromRGB(245, 245, 245) },
	{ id = "scuffed", name = "Scuffed", min = 0.35, max = 0.65, multiplier = 0.85, color = Color3.fromRGB(214, 180, 120), tint = Color3.fromRGB(215, 210, 200) },
	{ id = "oofd", name = "Oof'd", min = 0.65, max = 1, multiplier = 0.7, color = Color3.fromRGB(200, 120, 100), tint = Color3.fromRGB(170, 160, 150) },
}

local Condition = {}
Condition.list = LIST

function Condition.fromFloat(f: number): Band
	for _, band in LIST do
		if f < band.max then
			return band
		end
	end
	return LIST[#LIST]
end

-- luck makes low (better) floats more likely: the float is the best of luck ^ LUCK_POWER rolls, worked out in one
-- draw (the lowest of n uniform rolls is 1 - (1 - u) ^ (1 / n)). luck 100 is the best of 10 rolls, so Mint goes
-- from 3% to about 26%. case prices assume normal luck.
local LUCK_POWER = 0.5

function Condition.rollFloat(rng: Random, luck: number?): number
	local u = rng:NextNumber()
	if luck and luck > 1 then
		local rolls = math.min(luck, 1e300) ^ LUCK_POWER
		u = 1 - (1 - u) ^ (1 / rolls)
	end
	return math.floor(u * 1e6) / 1e6
end

local CLEAN_MIN, CLEAN_MAX = 0.12, 0.35
local BEST_BONUS, BEST_CURVE = 0.6, 1.5
local WORST_LOSS, WORST_CURVE = 0.4, 1.3

function Condition.multiplier(f: number): number
	if f < CLEAN_MIN then
		return 1 + BEST_BONUS * ((CLEAN_MIN - math.max(f, 0)) / CLEAN_MIN) ^ BEST_CURVE
	elseif f > CLEAN_MAX then
		return 1 - WORST_LOSS * ((math.min(f, 1) - CLEAN_MAX) / (1 - CLEAN_MAX)) ^ WORST_CURVE
	end
	return 1
end

-- average over a uniform float (normal luck), used for case pricing
local expected = 0
local STEPS = 10000
for i = 0, STEPS - 1 do
	expected += Condition.multiplier((i + 0.5) / STEPS)
end
expected /= STEPS

function Condition.expectedMultiplier(): number
	return expected
end

return Condition
