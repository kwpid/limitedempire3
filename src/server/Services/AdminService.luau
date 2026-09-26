-- developer tools. decides who is an admin and runs admin actions sent from the admin panel.
-- admins: anyone in ADMIN_USER_IDS, the place owner (or group rank 254+ for group games), and everyone in studio.
-- admins get the "IsAdmin" attribute on their player so the client knows to show the panel. every action is
-- checked again here, the attribute is only for ui.
--
-- api: AdminService:IsAdmin(player) -> boolean
-- actions (Net.functions.AdminAction:InvokeServer(action, payload)):
--   "addCash" { amount }  adds to your cash (negative removes)
--   "setCash" { amount }  sets your cash
--   "setLuck" { amount }  sets your luck multiplier (1 = normal)
--   "setNameStyle" { style } sets your overhead name style (ids from Shared.Visuals.NameStyles)
--   "wipeData"            resets your saved data (cash, inventory, equipped) to the template
--   "wipeAll"             wipeData plus restarts every serial counter at #1 (testing only)
-- to add an action, add a handler to ACTIONS below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local LuckService = require(script.Parent.LuckService)
local NameStyleService = require(script.Parent.NameStyleService)
local SerialService = require(script.Parent.SerialService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ADMIN_USER_IDS: { [number]: boolean } = {}

local GROUP_ADMIN_RANK = 254
local MAX_CASH = 1e15

local AdminService = {}

local admins: { [Player]: boolean } = {}

local function checkAdmin(player: Player): boolean
	if RunService:IsStudio() or ADMIN_USER_IDS[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= GROUP_ADMIN_RANK
end

local function readAmount(payload: any): number?
	local amount = type(payload) == "table" and payload.amount
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) > MAX_CASH then
		return nil
	end
	return math.floor(amount)
end

local ACTIONS: { [string]: (Player, any) -> Types.Result<any> } = {
	addCash = function(player, payload)
		local amount = readAmount(payload)
		if not amount then
			return { ok = false, err = "Invalid amount" }
		end
		PlayerDataService:AddCash(player, amount)
		return { ok = true }
	end,

	setCash = function(player, payload)
		local amount = readAmount(payload)
		if not amount or amount < 0 then
			return { ok = false, err = "Invalid amount" }
		end
		PlayerDataService:SetCash(player, amount)
		return { ok = true }
	end,

	setNameStyle = function(player, payload)
		local styleId = type(payload) == "table" and payload.style
		if not NameStyleService:Set(player, styleId) then
			return { ok = false, err = "Unknown name style" }
		end
		return { ok = true }
	end,

	wipeData = function(player)
		PlayerDataService:Reset(player)
		return { ok = true }
	end,

	wipeAll = function(player)
		PlayerDataService:Reset(player)
		local cleared = SerialService:ResetAll()
		return { ok = true, data = cleared }
	end,

	setLuck = function(player, payload)
		local luck = type(payload) == "table" and payload.amount
		if type(luck) ~= "number" or luck ~= luck or luck < 1 then
			return { ok = false, err = "Luck must be 1 or higher" }
		end
		LuckService:Set(player, luck)
		return { ok = true }
	end,
}

function AdminService:IsAdmin(player: Player): boolean
	return admins[player] == true
end

local function onPlayerAdded(player: Player)
	local isAdmin = checkAdmin(player)
	admins[player] = isAdmin
	player:SetAttribute("IsAdmin", isAdmin)
end

function AdminService:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		admins[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Net.functions.AdminAction.OnServerInvoke = function(player, action, payload)
		if not admins[player] then
			return { ok = false, err = "Not allowed" }
		end
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return { ok = false, err = "Unknown action" }
		end
		return handler(player, payload)
	end
end

return AdminService
