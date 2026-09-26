-- decides each player's overhead name style (see Shared.Visuals.NameStyles). stored as the "NameStyle" attribute
-- on the player so every client can render it. not saved yet, everyone starts on "default".
-- later this is where gamepasses, ranks or unlocks should pick the style.
-- api: NameStyleService:Get(player) -> style id, NameStyleService:Set(player, styleId) -> boolean (false if unknown id)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)

local ATTRIBUTE = "NameStyle"
local DEFAULT_STYLE = "default"

local NameStyleService = {}

function NameStyleService:Get(player: Player): string
	local id = player:GetAttribute(ATTRIBUTE)
	return if NameStyles.exists(id) then id else DEFAULT_STYLE
end

function NameStyleService:Set(player: Player, styleId: any): boolean
	if not NameStyles.exists(styleId) then
		return false
	end
	player:SetAttribute(ATTRIBUTE, styleId)
	return true
end

function NameStyleService:Init()
	local function onPlayerAdded(player: Player)
		if player:GetAttribute(ATTRIBUTE) == nil then
			player:SetAttribute(ATTRIBUTE, DEFAULT_STYLE)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return NameStyleService
