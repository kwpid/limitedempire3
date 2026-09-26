-- builds the playable cases from CaseData + SeriesRegistry: which items each case holds (its series plus guest
-- picks), per item odds, the hidden special pool, expected value and price. shared so the ui shows the exact odds
-- the server rolls with.
--
-- api: CaseRegistry.get(caseId) -> Case?, CaseRegistry.list() -> { Case } sorted by order,
-- CaseRegistry.caseSeries() -> { CaseSeries } in display order (each with its cases),
-- CaseRegistry.seriesFor(caseId, assetId) -> series id the item counts as when unboxed from that case,
-- CaseRegistry.itemSeries(item) -> series id of an item instance (its saved series, or worked out for old items),
-- CaseRegistry.roll(caseId, rng, luck?) -> assetId (server uses its own Random, client only for reel filler),
-- CaseRegistry.isSpecial(assetId) -> boolean (true for items hidden as "rare special items" in cases)
-- CaseRegistry.isAvailable(case) -> boolean (false for a season case outside its season; get() still finds it)
-- CaseRegistry.chanceOf(caseId?, assetId) -> number? (base odds of that item in that case, nil if not in it)
-- CaseRegistry.rollTier(caseId, tierId, rng) -> assetId? (odds weighted roll among the case's items of that tier,
-- nil if the case has none, used by admin test overrides)
-- luck (default 1) multiplies each item's odds by luck ^ rarity, where rarity goes from 0 (cheapest in the case)
-- to 1 (most expensive), so luck mostly boosts the special pool. there is no cap.

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local Seasons = require(Shared.Progress.Seasons)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Valuation = require(Shared.Modifiers.Valuation)
local SeriesRegistry = require(Shared.Series.SeriesRegistry)
local StableHash = require(Shared.Util.StableHash)
local CaseData = require(script.Parent.CaseData)

export type CaseItem = {
	assetId: number,
	weight: number,
	chance: number,
	value: number,
	rarity: number,
	special: boolean,
}

export type CaseSeries = {
	id: string,
	name: string,
	description: string,
	color: Color3,
	cases: { Case },
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
	image: string?,
	houseEdge: number,
	totalWeight: number,
	specialChance: number,
	specialCount: number,
	series: { string },
	seriesOf: { [number]: string },
	caseSeries: string?,
	topValue: number,
	season: number?,
}

local SPECIAL_MIN_VALUE = CaseData.specialMinValue

local function roundUpNice(n: number): number
	if n <= 0 then
		return 0
	end
	local magnitude = 10 ^ math.max(math.floor(math.log10(n)) - 2, 0)
	return math.ceil(n / magnitude) * magnitude
end

-- every item of the case's series, then guestCount picks per guest theme among its items worth guestMinValue+.
-- a case that ends up with no special item gets the least used one (ties broken by a stable hash), so every case
-- has at least one. seriesOf remembers which series each item counts as when it drops from this case.
local specialUses: { [number]: number } = {}
local specialPool: { number } = {}
for assetId in ItemRegistry.all() do
	if ItemRegistry.isEquippable(assetId) and ItemRegistry.baseValue(assetId) >= CaseData.specialMinValue then
		table.insert(specialPool, assetId)
	end
end
table.sort(specialPool)

local function gather(def): ({ number }, { [number]: string })
	local assetIds = {}
	local seriesOf = {}
	for _, seriesId in def.series do
		local series = SeriesRegistry.get(seriesId)
		assert(series, `case "{def.id}" uses unknown series "{seriesId}"`)
		for _, assetId in series.items do
			if not seriesOf[assetId] then
				seriesOf[assetId] = seriesId
				table.insert(assetIds, assetId)
			end
		end
	end

	local salt = StableHash.string(def.id) % 100_000
	for _, groupId in def.guests or {} do
		local pool = {}
		for _, assetId in SeriesRegistry.group(groupId) do
			if not seriesOf[assetId] and ItemRegistry.baseValue(assetId) >= CaseData.guestMinValue then
				table.insert(pool, assetId)
			end
		end
		table.sort(pool, function(a, b)
			return StableHash.number(a, salt) < StableHash.number(b, salt)
		end)
		for i = 1, math.min(CaseData.guestCount, #pool) do
			local assetId = pool[i]
			if not seriesOf[assetId] then
				seriesOf[assetId] = SeriesRegistry.of(assetId)[1]
				table.insert(assetIds, assetId)
			end
		end
	end

	local hasSpecial = false
	for _, assetId in assetIds do
		if ItemRegistry.baseValue(assetId) >= CaseData.specialMinValue then
			hasSpecial = true
			specialUses[assetId] = (specialUses[assetId] or 0) + 1
		end
	end
	if not hasSpecial and #specialPool > 0 then
		local best, bestUses, bestHash = nil, math.huge, math.huge
		for _, assetId in specialPool do
			local uses = specialUses[assetId] or 0
			local h = StableHash.number(assetId, salt)
			if uses < bestUses or (uses == bestUses and h < bestHash) then
				best, bestUses, bestHash = assetId, uses, h
			end
		end
		seriesOf[best] = SeriesRegistry.of(best)[1]
		table.insert(assetIds, best)
		specialUses[best] = bestUses + 1
	end
	return assetIds, seriesOf
end

local function build(def, order: number): Case?
	local assetIds, seriesOf = gather(def)
	-- def.specials: items (custom ones too, like a season case's top item) always in the hidden special pool
	local forced = {}
	for _, assetId in def.specials or {} do
		assert(ItemRegistry.get(assetId), `case "{def.id}" has an unknown special item {assetId}`)
		forced[assetId] = true
		if not table.find(assetIds, assetId) then
			table.insert(assetIds, assetId)
		end
	end
	local curve = CaseData.curve
	local normal, special = {}, {}
	for _, assetId in assetIds do
		local value = ItemRegistry.baseValue(assetId)
		local entry: CaseItem = {
			assetId = assetId,
			weight = math.max(value, 1) ^ -curve,
			chance = 0,
			value = value,
			rarity = 0,
			special = value >= SPECIAL_MIN_VALUE or forced[assetId] == true,
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

	local bestVisible = normal[1]
	for _, entry in normal do
		if entry.value > bestVisible.value then
			bestVisible = entry
		end
	end

	local expectedValue = expectedBase * Valuation.expectedModifierMultiplier()
	return {
		id = def.id,
		name = def.name,
		order = def.order or order,
		color = def.color or Color3.new(1, 1, 1),
		price = roundUpNice(expectedValue * (1 + (def.houseEdge or Config.HouseEdge))),
		houseEdge = def.houseEdge or Config.HouseEdge,
		expectedValue = expectedValue,
		items = items,
		iconAssetId = iconAssetId,
		image = if def.icon then `rbxassetid://{def.icon}` else nil,
		totalWeight = 1,
		specialChance = specialChance,
		specialCount = #special,
		series = def.series,
		seriesOf = seriesOf,
		caseSeries = nil,
		topValue = bestVisible.value,
		season = def.season,
	}
end

local byId: { [string]: Case } = {}
local ordered: { Case } = {}

for index, def in CaseData.cases do
	assert(not byId[def.id], `duplicate case id "{def.id}"`)
	local case = build(def, index)
	if case then
		byId[case.id] = case
		table.insert(ordered, case)
	end
end

table.sort(ordered, function(a, b)
	return a.order < b.order
end)

local seriesList: { CaseSeries } = {}
for _, def in CaseData.caseSeries or {} do
	local group: CaseSeries = {
		id = def.id,
		name = def.name,
		description = def.description or "",
		color = def.color or Color3.new(1, 1, 1),
		cases = {},
	}
	for _, caseId in def.cases do
		local case = byId[caseId]
		assert(case, `case series "{def.id}" uses unknown case "{caseId}"`)
		assert(not case.caseSeries, `case "{caseId}" is in more than one case series`)
		case.caseSeries = def.id
		table.insert(group.cases, case)
	end
	table.insert(seriesList, group)
end
local leftovers = {}
for _, case in ordered do
	if not case.caseSeries then
		case.caseSeries = "other"
		table.insert(leftovers, case)
	end
end
if #leftovers > 0 then
	table.insert(seriesList, {
		id = "other",
		name = "More Cases",
		description = "",
		color = Color3.new(1, 1, 1),
		cases = leftovers,
	})
end

local CaseRegistry = {}

function CaseRegistry.get(caseId: string): Case?
	return byId[caseId]
end

function CaseRegistry.isAvailable(case: Case): boolean
	return case.season == nil or case.season == Seasons.current()
end

function CaseRegistry.list(): { Case }
	return ordered
end

function CaseRegistry.caseSeries(): { CaseSeries }
	return seriesList
end

function CaseRegistry.seriesFor(caseId: string?, assetId: number): string?
	local case = caseId and byId[caseId]
	return (case and case.seriesOf[assetId]) or SeriesRegistry.of(assetId)[1]
end

function CaseRegistry.itemSeries(item: { assetId: number, caseId: string?, series: string? }): string?
	return item.series or CaseRegistry.seriesFor(item.caseId, item.assetId)
end

function CaseRegistry.isSpecial(assetId: number): boolean
	return ItemRegistry.baseValue(assetId) >= SPECIAL_MIN_VALUE
end

function CaseRegistry.chanceOf(caseId: string?, assetId: number): number?
	local case = caseId and byId[caseId]
	if not case then
		return nil
	end
	for _, item in case.items do
		if item.assetId == assetId then
			return item.chance
		end
	end
	return nil
end

function CaseRegistry.rollTier(caseId: string, tierId: string, rng: Random): number?
	local case = byId[caseId]
	if not case then
		return nil
	end
	local total = 0
	local matching = {}
	for _, item in case.items do
		if ItemRegistry.tier(item.assetId).id == tierId then
			table.insert(matching, item)
			total += item.weight
		end
	end
	if #matching == 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	for _, item in matching do
		r -= item.weight
		if r <= 0 then
			return item.assetId
		end
	end
	return matching[#matching].assetId
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
