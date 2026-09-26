-- saves settings changes sent from the settings window. every value is checked against Shared.Settings first.
-- client calls it through Net.functions.SetSetting:InvokeServer(id, value) -> { ok, err? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Settings = require(Shared.Settings)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

function SettingsService:Set(player: Player, id: any, value: any): Types.Result<nil>
	local cleaned = Settings.clean(id, value)
	if cleaned == nil then
		return { ok = false, err = "Invalid setting" }
	end
	PlayerDataService:SetSetting(player, id, cleaned)
	return { ok = true }
end

function SettingsService:Init()
	Net.functions.SetSetting.OnServerInvoke = function(player, id, value)
		return SettingsService:Set(player, id, value)
	end
end

return SettingsService
