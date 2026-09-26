-- per player luck multiplier used when rolling cases and traits. default is 1 (normal odds).
-- stored as the "Luck" attribute on the player so the client can show it, only the server ever sets it.
-- not saved yet, resets to 1 on rejoin.
-- api: LuckService:Get(player) -> number, LuckService:Set(player, luck) (minimum 1, no maximum)

local Players = game:GetService("Players")

local ATTRIBUTE = "Luck"
local DEFAULT_LUCK = 1
local MIN_LUCK = 1

local LuckService = {}

function LuckService:Get(player: Player): number
	local luck = player:GetAttribute(ATTRIBUTE)
	return if type(luck) == "number" then luck else DEFAULT_LUCK
end

function LuckService:Set(player: Player, luck: number)
	if luck ~= luck then
		return
	end
	player:SetAttribute(ATTRIBUTE, math.max(luck, MIN_LUCK))
end

function LuckService:Init()
	local function onPlayerAdded(player: Player)
		if player:GetAttribute(ATTRIBUTE) == nil then
			player:SetAttribute(ATTRIBUTE, DEFAULT_LUCK)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return LuckService
