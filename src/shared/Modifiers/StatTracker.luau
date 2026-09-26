-- stat trackers: a rare roll on unbox that counts how many cases the owner opens while the item is equipped.
-- having one multiplies the item's value by Config.StatTracker.Multiplier. the count never changes the value, so
-- keep it out of multiplier(). the count lives on the item itself (item.tracker.opens), so it stays with the item
-- when it changes hands (see PlayerDataService:TransferItems) and keeps counting for whoever equips it next.
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

-- only whether the item has a tracker matters, not how high the count is
function StatTracker.multiplier(tracker: Types.StatTracker?): number
	return if tracker then Config.StatTracker.Multiplier else 1
end

function StatTracker.expectedMultiplier(): number
	return 1 + Config.StatTracker.Chance * (Config.StatTracker.Multiplier - 1)
end

return StatTracker
