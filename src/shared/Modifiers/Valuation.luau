-- turns an item instance into its final value: base value * condition * trait * serial.
-- api: Valuation.value(item) -> number, Valuation.breakdown(item) -> { base, condition, trait, serial, total },
-- Valuation.expectedModifierMultiplier() -> average bonus from condition and traits (serials ignored)

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Types = require(Shared.Types)
local Condition = require(script.Parent.Condition)
local Traits = require(script.Parent.Traits)
local Serial = require(script.Parent.Serial)

local Valuation = {}

export type Breakdown = {
	base: number,
	condition: number,
	trait: number,
	serial: number,
	total: number,
}

function Valuation.breakdown(item: Types.ItemInstance): Breakdown
	local base = ItemRegistry.baseValue(item.assetId)
	local condition = Condition.fromFloat(item.float).multiplier
	local trait = Traits.multiplier(item.trait)
	local serial = Serial.multiplier(item.serial)
	return {
		base = base,
		condition = condition,
		trait = trait,
		serial = serial,
		total = math.floor(base * condition * trait * serial),
	}
end

function Valuation.value(item: Types.ItemInstance): number
	return Valuation.breakdown(item).total
end

function Valuation.expectedModifierMultiplier(): number
	return Condition.expectedMultiplier() * Traits.expectedMultiplier()
end

return Valuation
