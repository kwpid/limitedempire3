-- builds the playable cases from CaseData + every wearable item in ItemData: which case each item lands in,
-- per item odds, the hidden special pool, expected value and price. shared so the ui shows the exact odds the
-- server rolls with.
--
-- api: CaseRegistry.get(caseId) -> Case?, CaseRegistry.list() -> { Case } sorted by order,
-- CaseRegistry.roll(caseId, rng, luck?) -> assetId (server uses its own Random, client only for reel filler),
-- CaseRegistry.isSpecial(assetId) -> boolean (true for items hidden as "rare special items" in cases)
-- luck (default 1) multiplies each item's odds by luck ^ rarity, where rarity goes from 0 (cheapest in the case)
-- to 1 (most expensive), so luck mostly boosts the special pool. there is no cap.

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Tiers = require(Shared.Items.Tiers)
local Valuation = require(Shared.Modifiers.Valuation)
local CaseData = require(script.Parent.CaseData)

export type CaseItem = {
	assetId: number,
	weight: number,
	chance: number,
	value: number,
	rarity: number,
	special: boolean,
}

export type Case = {
	id: string,
	name: string,
	order: number,
	color: Color3,
	price: number,
	expectedValue: number,
	items: { CaseItem },
	iconAssetId: number,
	totalWeight: number,
	specialChance: number,
	specialCount: number,
}

local specialTier = Tiers.get(CaseData.specialTier)
assert(specialTier, `CaseData.specialTier "{CaseData.specialTier}" is not a tier`)
local SPECIAL_MIN_VALUE = specialTier.minValue

local function roundUpNice(n: number): number
	if n <= 0 then
		return 0
	end
	local magnitude = 10 ^ math.max(math.floor(math.log10(n)) - 2, 0)
	return math.ceil(n / magnitude) * magnitude
end

local function hash(assetId: number, salt: number): number
	local h = bit32.bxor(2166136261, salt)
	local text = tostring(assetId)
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return h
end

local function assignItems(): { { number } }
	local buckets = {}
	for i = 1, #CaseData.cases do
		buckets[i] = {}
	end
	for assetId in ItemRegistry.all() do
		if ItemRegistry.isEquippable(assetId) and ItemRegistry.baseValue(assetId) > 0 then
			local index = hash(assetId, CaseData.salt) % #CaseData.cases + 1
			table.insert(buckets[index], assetId)
		end
	end
	return buckets
end

local function build(def, assetIds: { number }): Case?
	local curve = CaseData.curve
	local normal, special = {}, {}
	for _, assetId in assetIds do
		local value = ItemRegistry.baseValue(assetId)
		local entry: CaseItem = {
			assetId = assetId,
			weight = value ^ -curve,
			chance = 0,
			value = value,
			rarity = 0,
			special = value >= SPECIAL_MIN_VALUE,
		}
		table.insert(if entry.special then special else normal, entry)
	end
	if #normal == 0 then
		warn(`[CaseRegistry] case "{def.id}" has no regular items, skipping it`)
		return nil
	end

	local specialChance = if #special > 0 then CaseData.specialChance else 0
	local function normalize(group: { CaseItem }, share: number)
		local total = 0
		for _, entry in group do
			total += entry.weight
		end
		for _, entry in group do
			entry.weight = share * entry.weight / total
			entry.chance = entry.weight
		end
	end
	normalize(normal, 1 - specialChance)
	if #special > 0 then
		normalize(special, specialChance)
	end

	local items: { CaseItem } = table.clone(normal)
	table.move(special, 1, #special, #items + 1, items)
	table.sort(items, function(a, b)
		if a.value == b.value then
			return a.assetId < b.assetId
		end
		return a.value > b.value
	end)

	local low, high = math.log(items[#items].value), math.log(items[1].value)
	local expectedBase = 0
	for _, item in items do
		item.rarity = if high > low then (math.log(item.value) - low) / (high - low) else 0
		expectedBase += item.chance * item.value
	end

	local iconAssetId = items[1].assetId
	for _, item in items do
		if not item.special then
			iconAssetId = item.assetId
			break
		end
	end

	local expectedValue = expectedBase * Valuation.expectedModifierMultiplier()
	return {
		id = def.id,
		name = def.name,
		order = def.order or 0,
		color = def.color or Color3.new(1, 1, 1),
		price = roundUpNice(expectedValue * (1 + Config.HouseEdge)),
		expectedValue = expectedValue,
		items = items,
		iconAssetId = iconAssetId,
		totalWeight = 1,
		specialChance = specialChance,
		specialCount = #special,
	}
end

local byId: { [string]: Case } = {}
local ordered: { Case } = {}

local buckets = assignItems()
for index, def in CaseData.cases do
	assert(not byId[def.id], `duplicate case id "{def.id}"`)
	local case = build(def, buckets[index])
	if case then
		byId[case.id] = case
		table.insert(ordered, case)
	end
end

table.sort(ordered, function(a, b)
	return a.order < b.order
end)

local CaseRegistry = {}

function CaseRegistry.get(caseId: string): Case?
	return byId[caseId]
end

function CaseRegistry.list(): { Case }
	return ordered
end

function CaseRegistry.isSpecial(assetId: number): boolean
	return ItemRegistry.baseValue(assetId) >= SPECIAL_MIN_VALUE
end

function CaseRegistry.roll(caseId: string, rng: Random, luck: number?): number
	local case = byId[caseId]
	assert(case, `unknown case "{caseId}"`)
	local boost = if luck and luck > 1 then math.min(luck, 1e300) else 1

	if boost == 1 then
		local r = rng:NextNumber() * case.totalWeight
		for _, item in case.items do
			r -= item.weight
			if r <= 0 then
				return item.assetId
			end
		end
		return case.items[#case.items].assetId
	end

	local logBoost = math.log(boost)
	local logs = table.create(#case.items)
	local highest = -math.huge
	for i, item in case.items do
		logs[i] = math.log(item.weight) + item.rarity * logBoost
		highest = math.max(highest, logs[i])
	end
	local total = 0
	for i, value in logs do
		logs[i] = math.exp(value - highest)
		total += logs[i]
	end

	local r = rng:NextNumber() * total
	for i, item in case.items do
		r -= logs[i]
		if r <= 0 then
			return item.assetId
		end
	end
	return case.items[#case.items].assetId
end

return CaseRegistry
