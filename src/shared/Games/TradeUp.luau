-- trade-up contract rules, shared so the ui shows the exact outcomes and odds the server rolls with.
-- the player gives COUNT items of the same rarity (a value tier below Divine, custom rarities can't be used) and
-- gets one item of the next rarity. each input is an equal ticket: its series decides the pool, and the result is
-- picked evenly from that series' items of the next rarity worth at most MAX_RETURN times the total put in (so
-- trading up the cheapest items of a rarity can't be a guaranteed profit). when the series has none, any item of
-- that rarity under the cap is used, and when nothing is under the cap, the cheapest items of that rarity.
-- the new item's float is the average float of the inputs, it has no trait or stat tracker.
-- equipped and pinned items can't be used.
-- api: TradeUp.nextTier(tierId) -> Tier?, TradeUp.pool(seriesId?, tierId, maxValue) -> { assetId },
-- TradeUp.maxValue(items) -> number,
-- TradeUp.outcomes(items) -> { { assetId, chance } } sorted by chance, TradeUp.float(items) -> number,
-- TradeUp.check(items) -> (ok, err?) (same rarity, right count, a tier that can go up)

local Shared = script.Parent.Parent
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local SeriesRegistry = require(Shared.Series.SeriesRegistry)
local Tiers = require(Shared.Items.Tiers)

local TradeUp = {}

TradeUp.COUNT = 10
TradeUp.MAX_RETURN = 1.7
TradeUp.FALLBACK_SIZE = 5

function TradeUp.nextTier(tierId: string): Tiers.Tier?
	for index, tier in Tiers.list do
		if tier.id == tierId then
			local nextTier = Tiers.list[index + 1]
			-- nothing trades up into the hidden special tier
			return if nextTier and nextTier.id ~= "divine" then nextTier else nil
		end
	end
	return nil
end

local byTier: { [string]: { number } } = {}
local function allOfTier(tierId: string): { number }
	if not byTier[tierId] then
		local list = {}
		for assetId in ItemRegistry.all() do
			if
				ItemRegistry.isEquippable(assetId)
				and ItemRegistry.baseValue(assetId) > 0
				and ItemRegistry.tier(assetId).id == tierId
			then
				table.insert(list, assetId)
			end
		end
		table.sort(list)
		byTier[tierId] = list
	end
	return byTier[tierId]
end

function TradeUp.pool(seriesId: string?, tierId: string, maxValue: number): { number }
	local series = seriesId and SeriesRegistry.get(seriesId)
	if series then
		local list = {}
		for _, assetId in series.items do
			if ItemRegistry.tier(assetId).id == tierId and ItemRegistry.baseValue(assetId) <= maxValue then
				table.insert(list, assetId)
			end
		end
		if #list > 0 then
			return list
		end
	end
	local all = allOfTier(tierId)
	local list = {}
	for _, assetId in all do
		if ItemRegistry.baseValue(assetId) <= maxValue then
			table.insert(list, assetId)
		end
	end
	if #list > 0 then
		return list
	end
	local cheapest = table.clone(all)
	table.sort(cheapest, function(a, b)
		return ItemRegistry.baseValue(a) < ItemRegistry.baseValue(b)
	end)
	return { table.unpack(cheapest, 1, math.min(TradeUp.FALLBACK_SIZE, #cheapest)) }
end

-- the most a result can be worth: MAX_RETURN times the base value put in
function TradeUp.maxValue(items): number
	local total = 0
	for _, item in items do
		total += ItemRegistry.baseValue(item.assetId)
	end
	return total * TradeUp.MAX_RETURN
end

function TradeUp.check(items): (boolean, string?)
	if #items ~= TradeUp.COUNT then
		return false, `Pick exactly {TradeUp.COUNT} items`
	end
	local tierId = nil
	for _, item in items do
		if ItemRegistry.isCustom(item.assetId) then
			return false, "Custom items can't be traded up"
		end
		local id = ItemRegistry.tier(item.assetId).id
		tierId = tierId or id
		if id ~= tierId then
			return false, "All items must be the same rarity"
		end
	end
	if not TradeUp.nextTier(tierId :: string) then
		return false, "That rarity can't be traded up"
	end
	return true, nil
end

function TradeUp.outcomes(items): { { assetId: number, chance: number } }
	if #items == 0 then
		return {}
	end
	local nextTier = TradeUp.nextTier(ItemRegistry.tier(items[1].assetId).id)
	if not nextTier then
		return {}
	end
	local chances: { [number]: number } = {}
	local maxValue = TradeUp.maxValue(items)
	for _, item in items do
		local pool = TradeUp.pool(CaseRegistry.itemSeries(item), nextTier.id, maxValue)
		for _, assetId in pool do
			chances[assetId] = (chances[assetId] or 0) + 1 / #items / #pool
		end
	end
	local list = {}
	for assetId, chance in chances do
		table.insert(list, { assetId = assetId, chance = chance })
	end
	table.sort(list, function(a, b)
		if a.chance == b.chance then
			return ItemRegistry.baseValue(a.assetId) > ItemRegistry.baseValue(b.assetId)
		end
		return a.chance > b.chance
	end)
	return list
end

function TradeUp.float(items): number
	local total = 0
	for _, item in items do
		total += item.float
	end
	return math.floor(total / math.max(#items, 1) * 1e6) / 1e6
end

return TradeUp
