-- timed multipliers (see Shared/Economy/Boosts). saved in data.boosts[kind] = { multiplier, endsAt } (os.time) and
-- mirrored to player attributes Boost_<kind> / Boost_<kind>_ends while active.
-- api: BoostService:Multiplier(player, kind) -> number (1 when none), BoostService:Add(player, kind, multiplier,
-- minutes)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Economy.Boosts)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BoostService = {}

local CHECK_EVERY = 5

local function boostsOf(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	data.boosts = data.boosts or {}
	return data.boosts
end

-- attributes for the active boosts, cleared for expired ones
local function sync(player: Player)
	local boosts = boostsOf(player)
	if not boosts then
		return
	end
	local now = os.time()
	for _, kind in Boosts.ORDER do
		local boost = boosts[kind]
		local active = boost and boost.endsAt > now
		player:SetAttribute(Boosts.attribute(kind), if active then boost.multiplier else nil)
		player:SetAttribute(Boosts.endsAttribute(kind), if active then boost.endsAt else nil)
		if boost and not active then
			boosts[kind] = nil
		end
	end
end

function BoostService:Multiplier(player: Player, kind: string): number
	local boosts = boostsOf(player)
	local boost = boosts and boosts[kind]
	if boost and boost.endsAt > os.time() then
		return boost.multiplier
	end
	return 1
end

function BoostService:Add(player: Player, kind: string, multiplier: number, minutes: number)
	local boosts = boostsOf(player)
	if not boosts or not Boosts.KINDS[kind] or not (multiplier > 1) or not (minutes > 0) then
		return
	end
	local now = os.time()
	local boost = boosts[kind]
	if boost and boost.endsAt > now then
		boost.multiplier = math.max(boost.multiplier, multiplier)
		boost.endsAt += math.floor(minutes * 60)
	else
		boosts[kind] = { multiplier = multiplier, endsAt = now + math.floor(minutes * 60) }
	end
	sync(player)
end

function BoostService:Init()
	PlayerDataService.Loaded:Connect(sync)
end

function BoostService:Start()
	while true do
		task.wait(CHECK_EVERY)
		for _, player in Players:GetPlayers() do
			sync(player)
		end
	end
end

return BoostService
