-- Season Points for opening a case: a base from the case price (1 to 3 for cheap cases, up to 15 for premium ones),
-- times a bonus for the rarity pulled, plus a little extra when the item is worth more than the case cost.
-- the event multiplier (Seasons.SP_MULTIPLIER or the live admin value) is applied by the server on top.
-- api: SeasonPoints.forCase(price, item) -> number

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)

local SeasonPoints = {}

SeasonPoints.PRICE_PER_SP = 2_500
SeasonPoints.MAX_BASE = 15

SeasonPoints.RARITY_BONUS = {
	epic = 1.5,
	legendary = 2,
	mythic = 3,
	exotic = 5,
	divine = 10,
}

SeasonPoints.TRAIT_BONUS = 1.5
SeasonPoints.MAX_PROFIT_BONUS = 5

function SeasonPoints.forCase(price: number, item): number
	local base = math.clamp(math.floor(price / SeasonPoints.PRICE_PER_SP + 0.5), 1, SeasonPoints.MAX_BASE)
	local multiplier = SeasonPoints.RARITY_BONUS[ItemRegistry.tier(item.assetId).id] or 1
	if #Traits.of(item) > 0 then
		multiplier *= SeasonPoints.TRAIT_BONUS
	end
	local sp = base * multiplier
	local value = Valuation.value(item)
	if price > 0 and value > price then
		sp += math.min(math.floor(math.log(value / price, 2)) + 1, SeasonPoints.MAX_PROFIT_BONUS)
	end
	return math.floor(sp + 0.5)
end

return SeasonPoints
