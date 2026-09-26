-- owns every player's saved state (cash, inventory, equipped) and replicates changes to that player's client.
-- all state changes must go through this service so the client stays in sync. data is saved with ProfileStore
-- (session locked, autosaves, saves on leave and shutdown). store names and the template live in DataConfig.
-- in studio without api access ProfileStore falls back to a mock store, so nothing persists between tests.
--
-- api:
--   PlayerDataService:Get(player) -> PlayerState? (read only, do not mutate directly)
--   PlayerDataService:GetCash(player) -> number
--   PlayerDataService:AddCash(player, amount), PlayerDataService:SetCash(player, amount)
--   PlayerDataService:TrySpend(player, amount) -> boolean
--   PlayerDataService:AddItem(player, item)
--   PlayerDataService:GetItem(player, uid) -> ItemInstance?
--   PlayerDataService:RemoveItems(player, uids) -> { ItemInstance } (the ones that existed)
--   PlayerDataService:SetEquipped(player, uids)
--   PlayerDataService:UpdateItems(player, uids, mutate) -> { ItemInstance } calls mutate(item) on each owned item,
--   the ones it returns true for are replicated as changed (used for stat tracker counts)
--   PlayerDataService:Reset(player) (wipes the player back to the template, used by the admin panel)
--   PlayerDataService.Loaded (signal: player), PlayerDataService.EquippedChanged (signal: player, uids),
--   PlayerDataService.InventoryChanged (signal: player) fires after items are added, removed or wiped

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local DataConfig = require(ServerScriptService.Server.Modules.DataConfig)

type ItemInstance = Types.ItemInstance
type SavedData = { cash: number, inventory: { [string]: ItemInstance }, equipped: { string } }

local PlayerDataService = {
	InventoryChanged = Signal.new(),
	Loaded = Signal.new(),
	EquippedChanged = Signal.new(),
}

local store = ProfileStore.New(DataConfig.PlayerStore, DataConfig.template())
local profiles: { [Player]: any } = {}
local versions: { [Player]: number } = {}

local function dataOf(player: Player): SavedData?
	local profile = profiles[player]
	return profile and profile.Data
end

local function snapshot(player: Player): Types.PlayerState?
	local data = dataOf(player)
	if not data then
		return nil
	end
	return {
		cash = data.cash,
		inventory = data.inventory,
		equipped = data.equipped,
		version = versions[player] or 0,
	}
end

local function push(player: Player, kind: string, payload: any)
	if not profiles[player] then
		return
	end
	local version = (versions[player] or 0) + 1
	versions[player] = version
	Net.events.StateDelta:FireClient(player, version, kind, payload)
end

function PlayerDataService:Get(player: Player): Types.PlayerState?
	return snapshot(player)
end

function PlayerDataService:GetCash(player: Player): number
	local data = dataOf(player)
	return data and data.cash or 0
end

function PlayerDataService:AddCash(player: Player, amount: number)
	local data = dataOf(player)
	if not data or amount ~= amount or amount == 0 then
		return
	end
	data.cash = math.max(0, math.floor(data.cash + amount))
	push(player, "cash", data.cash)
end

function PlayerDataService:SetCash(player: Player, amount: number)
	local data = dataOf(player)
	if not data or not (amount >= 0) then
		return
	end
	data.cash = math.floor(amount)
	push(player, "cash", data.cash)
end

function PlayerDataService:TrySpend(player: Player, amount: number): boolean
	local data = dataOf(player)
	if not data or not (amount >= 0) or data.cash < amount then
		return false
	end
	data.cash -= amount
	push(player, "cash", data.cash)
	return true
end

function PlayerDataService:AddItem(player: Player, item: ItemInstance)
	local data = dataOf(player)
	if not data then
		return
	end
	data.inventory[item.uid] = item
	push(player, "add", item)
	self.InventoryChanged:Fire(player)
end

function PlayerDataService:GetItem(player: Player, uid: string): ItemInstance?
	local data = dataOf(player)
	return data and data.inventory[uid]
end

function PlayerDataService:RemoveItems(player: Player, uids: { string }): { ItemInstance }
	local data = dataOf(player)
	if not data then
		return {}
	end

	local removed = {}
	local removedUids = {}
	for _, uid in uids do
		local item = data.inventory[uid]
		if item then
			data.inventory[uid] = nil
			table.insert(removed, item)
			removedUids[uid] = true
		end
	end
	if #removed == 0 then
		return removed
	end

	local keptEquipped = {}
	for _, uid in data.equipped do
		if not removedUids[uid] then
			table.insert(keptEquipped, uid)
		end
	end

	local uidList = {}
	for _, item in removed do
		table.insert(uidList, item.uid)
	end
	push(player, "remove", uidList)
	self.InventoryChanged:Fire(player)

	if #keptEquipped ~= #data.equipped then
		self:SetEquipped(player, keptEquipped)
	end
	return removed
end

function PlayerDataService:UpdateItems(player: Player, uids: { string }, mutate: (ItemInstance) -> boolean): { ItemInstance }
	local data = dataOf(player)
	if not data then
		return {}
	end
	local changed = {}
	for _, uid in uids do
		local item = data.inventory[uid]
		if item and mutate(item) then
			table.insert(changed, item)
		end
	end
	if #changed > 0 then
		push(player, "update", changed)
	end
	return changed
end

function PlayerDataService:SetEquipped(player: Player, uids: { string })
	local data = dataOf(player)
	if not data then
		return
	end
	data.equipped = table.clone(uids)
	push(player, "equipped", data.equipped)
	self.EquippedChanged:Fire(player, data.equipped)
end

function PlayerDataService:Reset(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	local hadEquipped = #data.equipped > 0
	local fresh = DataConfig.template()
	for key in data do
		data[key] = nil
	end
	for key, value in fresh do
		data[key] = value
	end
	push(player, "replace", { cash = data.cash, inventory = data.inventory, equipped = data.equipped })
	self.InventoryChanged:Fire(player)
	if hadEquipped then
		self.EquippedChanged:Fire(player, data.equipped)
	end
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Your data could not be loaded, please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		versions[player] = nil
		if player.Parent == Players then
			player:Kick("Your data session ended, please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	versions[player] = 0
	PlayerDataService.Loaded:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

function PlayerDataService:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Net.functions.GetState.OnServerInvoke = function(player: Player)
		local timeout = os.clock() + 15
		while not profiles[player] and player.Parent and os.clock() < timeout do
			task.wait()
		end
		return snapshot(player)
	end
end

return PlayerDataService
