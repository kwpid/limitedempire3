-- item condition, driven by a float from 0 to 1 (lower is better). each band has a value multiplier and an avatar tint.
-- api: Condition.list, Condition.fromFloat(f) -> band, Condition.rollFloat(rng) -> number,
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

function Condition.rollFloat(rng: Random): number
	return math.floor(rng:NextNumber() * 1e6) / 1e6
end

local expected = 0
for _, band in LIST do
	expected += (band.max - band.min) * band.multiplier
end

function Condition.expectedMultiplier(): number
	return expected
end

return Condition
