-- titles and name styles: which ones each player owns and which one of each they have equipped.
-- owned = everything granted to their role (the "grant" field in Shared.Titles / Shared.Visuals.NameStyles) plus
-- whatever was unlocked and saved on them (quests and events later call Unlock). admins own everything so they
-- can test. equipped choices are saved and mirrored to player attributes for every client to render:
--   "Title" / "NameStyle" (equipped id), "OwnedTitles" / "OwnedNameStyles" (json list of ids)
-- api: CosmeticService:Owns(player, kind, id) -> boolean, CosmeticService:Owned(player, kind) -> { id },
-- CosmeticService:Unlock(player, kind, id), CosmeticService:Equip(player, kind, id) -> { ok, err? }
-- kinds: "title", "nameStyle". client equips through Net.functions.SetCosmetic:InvokeServer(kind, id)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local NameStyles = require(Shared.Visuals.NameStyles)
local Titles = require(Shared.Titles)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Kind = {
	list: { any },
	default: string,
	attribute: string,
	ownedAttribute: string,
}

local KINDS: { [string]: Kind } = {
	title = {
		list = Titles.list,
		default = Titles.NONE,
		attribute = "Title",
		ownedAttribute = "OwnedTitles",
	},
	nameStyle = {
		list = NameStyles.list,
		default = "default",
		attribute = "NameStyle",
		ownedAttribute = "OwnedNameStyles",
	},
}

local CosmeticService = {}

-- user ids that get the "moderator" grant
CosmeticService.MODERATOR_USER_IDS = {} :: { [number]: boolean }

-- AdminService sets IsAdmin on the server, reading the attribute avoids a require loop with AdminService
local function isAdmin(player: Player): boolean
	return player:GetAttribute("IsAdmin") == true
end

local function find(kind: Kind, id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	for _, entry in kind.list do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function CosmeticService:Owns(player: Player, kindId: string, id: any): boolean
	local kind = KINDS[kindId]
	local entry = kind and find(kind, id)
	if not entry then
		return false
	end
	if entry.grant == "everyone" or isAdmin(player) then
		return true
	end
	if entry.grant == "moderator" and CosmeticService.MODERATOR_USER_IDS[player.UserId] then
		return true
	end
	return table.find(PlayerDataService:GetCosmetics(player, kindId).unlocked, id) ~= nil
end

function CosmeticService:Owned(player: Player, kindId: string): { string }
	local owned = {}
	for _, entry in KINDS[kindId].list do
		if CosmeticService:Owns(player, kindId, entry.id) then
			table.insert(owned, entry.id)
		end
	end
	return owned
end

local function publish(player: Player)
	if not player.Parent or not PlayerDataService:Get(player) then
		return
	end
	for kindId, kind in KINDS do
		local equipped = PlayerDataService:GetCosmetics(player, kindId).equipped or kind.default
		if not CosmeticService:Owns(player, kindId, equipped) then
			equipped = kind.default
			PlayerDataService:SetEquippedCosmetic(player, kindId, equipped)
		end
		player:SetAttribute(kind.attribute, equipped)
		player:SetAttribute(kind.ownedAttribute, HttpService:JSONEncode(CosmeticService:Owned(player, kindId)))
	end
end

function CosmeticService:Unlock(player: Player, kindId: string, id: string)
	local kind = KINDS[kindId]
	if kind and find(kind, id) then
		PlayerDataService:UnlockCosmetic(player, kindId, id)
		publish(player)
	end
end

function CosmeticService:Equip(player: Player, kindId: any, id: any): Types.Result<nil>
	if type(kindId) ~= "string" or not KINDS[kindId] then
		return { ok = false, err = "Unknown cosmetic" }
	end
	if not CosmeticService:Owns(player, kindId, id) then
		return { ok = false, err = "You don't own that yet" }
	end
	PlayerDataService:SetEquippedCosmetic(player, kindId, id)
	publish(player)
	return { ok = true }
end

function CosmeticService:Init()
	PlayerDataService.Loaded:Connect(publish)
	-- a data wipe resets cosmetics too, keep the attributes in step
	PlayerDataService.InventoryChanged:Connect(function(player)
		for kindId, kind in KINDS do
			local saved = PlayerDataService:GetCosmetics(player, kindId).equipped or kind.default
			if player:GetAttribute(kind.attribute) ~= saved then
				publish(player)
				return
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
			publish(player)
		end)
	end)
	Net.functions.SetCosmetic.OnServerInvoke = function(player, kindId, id)
		return CosmeticService:Equip(player, kindId, id)
	end
	for _, player in Players:GetPlayers() do
		if PlayerDataService:Get(player) then
			task.spawn(publish, player)
		end
	end
end

return CosmeticService
