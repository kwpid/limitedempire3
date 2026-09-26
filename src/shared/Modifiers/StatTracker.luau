-- stat trackers: a rare roll on unbox that counts how many cases the owner opens while the item is equipped.
-- having one multiplies the item's value by Config.StatTracker.Multiplier, the count is for show.
-- api: StatTracker.roll(rng) -> StatTracker?, StatTracker.multiplier(tracker?) -> number,
-- StatTracker.expectedMultiplier() -> number

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local StatTracker = {}

function StatTracker.roll(rng: Random): Types.StatTracker?
	if rng:NextNumber() < Config.StatTracker.Chance then
		return { opens = 0 }
	end
	return nil
end

function StatTracker.multiplier(tracker: Types.StatTracker?): number
	return if tracker then Config.StatTracker.Multiplier else 1
end

function StatTracker.expectedMultiplier(): number
	return 1 + Config.StatTracker.Chance * (Config.StatTracker.Multiplier - 1)
end

return StatTracker
