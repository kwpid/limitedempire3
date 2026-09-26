-- upgrader rules, shared so the ui shows the exact odds the server rolls with.
-- the player puts in up to MAX_INPUTS items and picks a more valuable target item. the chance to win is the value
-- put in divided by the target's base value, minus the house edge, capped at MAX_CHANCE. win: the inputs are gone
-- and the player gets a fresh copy of the target (normal float and serial, no trait or stat tracker). lose: the
-- inputs are gone. equipped and pinned items can't be put in.
-- api: Upgrader.chance(inputValue, targetValue) -> number (0 when the target is not allowed),
-- Upgrader.canTarget(assetId) -> boolean, Upgrader.targets() -> { assetId } sorted by value

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)

local Upgrader = {}

Upgrader.MAX_INPUTS = 6
Upgrader.HOUSE_EDGE = 0.08
Upgrader.MAX_CHANCE = 0.75
Upgrader.MIN_CHANCE = 0.01

function Upgrader.canTarget(assetId: number): boolean
	return not ItemRegistry.isCustom(assetId)
		and ItemRegistry.isEquippable(assetId)
		and ItemRegistry.baseValue(assetId) > 0
end

function Upgrader.chance(inputValue: number, targetValue: number): number
	if inputValue <= 0 or targetValue <= inputValue then
		return 0
	end
	local chance = inputValue / targetValue * (1 - Upgrader.HOUSE_EDGE)
	if chance < Upgrader.MIN_CHANCE then
		return 0
	end
	return math.min(chance, Upgrader.MAX_CHANCE)
end

local sorted: { number }? = nil
function Upgrader.targets(): { number }
	if not sorted then
		local list = {}
		for assetId in ItemRegistry.all() do
			if Upgrader.canTarget(assetId) then
				table.insert(list, assetId)
			end
		end
		table.sort(list, function(a, b)
			local av, bv = ItemRegistry.baseValue(a), ItemRegistry.baseValue(b)
			if av == bv then
				return a < b
			end
			return av < bv
		end)
		sorted = list
	end
	return sorted :: { number }
end

return Upgrader
