-- turns an item instance into its final value: base value * condition * trait * serial * stat tracker.
-- api: Valuation.value(item) -> number, Valuation.breakdown(item) -> { base, condition, trait, serial, tracker, total },
-- Valuation.expectedModifierMultiplier() -> average bonus from condition, traits and trackers (serials ignored)

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Types = require(Shared.Types)
local Condition = require(script.Parent.Condition)
local Traits = require(script.Parent.Traits)
local Serial = require(script.Parent.Serial)
local StatTracker = require(script.Parent.StatTracker)

local Valuation = {}

export type Breakdown = {
	base: number,
	condition: number,
	trait: number,
	serial: number,
	tracker: number,
	total: number,
}

function Valuation.breakdown(item: Types.ItemInstance): Breakdown
	local base = ItemRegistry.baseValue(item.assetId)
	local condition = Condition.multiplier(item.float)
	local trait = Traits.combinedMultiplier(Traits.of(item))
	local serial = Serial.multiplier(item.serial)
	local tracker = StatTracker.multiplier(item.tracker)
	return {
		base = base,
		condition = condition,
		trait = trait,
		serial = serial,
		tracker = tracker,
		total = math.floor(base * condition * trait * serial * tracker),
	}
end

function Valuation.value(item: Types.ItemInstance): number
	return Valuation.breakdown(item).total
end

function Valuation.expectedModifierMultiplier(): number
	return Condition.expectedMultiplier() * Traits.expectedMultiplier() * StatTracker.expectedMultiplier()
end

return Valuation
