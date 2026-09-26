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
--   PlayerDataService:SetPinned(player, uid, pinned) pins or unpins an owned item (pins belong to the player, they
--   are dropped when the item leaves the inventory)
--   PlayerDataService:TransferItems(from, to, uids) -> { ItemInstance } moves the exact item records to another
--   player (for trading), so uid, serial, traits, stat tracker count, series and OG owner all carry over
--   PlayerDataService:UpdateItems(player, uids, mutate) -> { ItemInstance } calls mutate(item) on each owned item,
--   the ones it returns true for are replicated as changed (used for stat tracker counts)
--   PlayerDataService:SetSetting(player, id, value) (value must already be cleaned with Settings.clean)
--   PlayerDataService:GetSettings(player) -> resolved settings (defaults filled in)
--   PlayerDataService:AddStats(player, { [id]: amount }), PlayerDataService:SetStats(player, { [id]: value })
--   PlayerDataService:GetCosmetics(player, kind) -> { equipped, unlocked } (titles and name styles, saved
--   unlocks only, CosmeticService adds role grants), :SetEquippedCosmetic(player, kind, id),
--   :UnlockCosmetic(player, kind, id)
--   PlayerDataService:ViewUser(userId) -> (data?, where) and PlayerDataService:EditUser(userId, mutate) -> (ok, err?)
--   are for the admin data editor. they work on the live data when the player is in this server ("here"), on
--   the saved profile when they are offline ("offline", saved with ProfileStore SetAsync) and refuse to edit when
--   the player is in another server ("elsewhere", that server's session would overwrite the change).
--   where can also be "none" (never played) or "error" (datastore failed).
--   PlayerDataService:GetData(player) -> the raw saved data (mutable, server only, for services that own a part of
--   it like ProgressService), PlayerDataService:Push(player, kind, payload) sends a delta to that player
--   PlayerDataService:GetDaily(player, today) -> the player's daily counters (mutable, reset when the day changes)
--   PlayerDataService:Reset(player) (wipes the player back to the template, used by the admin panel)
--   PlayerDataService.Loaded (signal: player), PlayerDataService.EquippedChanged (signal: player, uids),
--   PlayerDataService.InventoryChanged (signal: player) fires after items are added, removed or wiped
--   PlayerDataService.Leaving (signal: player) fires when a player leaves, before their data is saved and closed
--
-- profile messages (for trading, which works between players in any server or offline):
--   PlayerDataService:SetMessageHandler(fn(ctx, message) -> ()) handles every message sent to a profile. ctx is
--   { data, player?, userId, send(toUserId, message, pump?) }: player is set when that player is in this server,
--   otherwise data is an offline profile this server opened for a moment (see Pump). a handler that errors leaves
--   the message to be handled again next session, so handlers must be safe to run twice.
--   PlayerDataService:SendMessage(player, toUserId, message, pump?) queues a message from this player's profile.
--   messages go out through an outbox saved in the sender's data and are only sent once the change that queued
--   them has been saved, so a server crash can never deliver a message for a change that was lost (no dupes).
--   the outbox resends anything unsent next session, so a message can arrive twice: receivers must ignore repeats.
--   pump = true opens the receiver's profile here for a moment when they are offline, so the message is handled
--   right away instead of when they next join.
--   PlayerDataService:GiveItems(player, items) adds exact item records (uids kept), :CleanRefs(data) drops
--   equipped / pinned uids that are no longer owned (for offline data)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local Settings = require(Shared.Settings)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local DataConfig = require(ServerScriptService.Server.Modules.DataConfig)

type ItemInstance = Types.ItemInstance
type SavedData = {
	cash: number,
	inventory: { [string]: ItemInstance },
	equipped: { string },
	pinned: { string },
	daily: { day: number, hiloEarned: number },
	settings: { [string]: any },
	stats: { [string]: number },
	cosmetics: { [string]: { equipped: string?, unlocked: { string } } },
	trades: { [string]: any },
	tradeOutbox: { OutboxEntry },
}
type OutboxEntry = { key: string, to: number, message: any, pump: boolean? }

local PlayerDataService = {
	InventoryChanged = Signal.new(),
	Loaded = Signal.new(),
	EquippedChanged = Signal.new(),
	Leaving = Signal.new(),
}

local store = ProfileStore.New(DataConfig.PlayerStore, DataConfig.template())
local profiles: { [Player]: any } = {}
local versions: { [Player]: number } = {}

local messageHandler: ((ctx: any, message: any) -> ())? = nil
-- os.clock() when an outbox entry was queued in this server. entries loaded from the datastore have none, they are
-- already saved and can go out right away
local outboxQueuedAt: { [string]: number } = {}
local outboxSending: { [string]: boolean } = {}
local saveQueued: { [any]: boolean } = {}
-- user ids whose offline profile this server has open to handle their messages
local pumping: { [number]: boolean } = {}

local function dataOf(player: Player): SavedData?
	local profile = profiles[player]
	return profile and profile.Data
end

-- the progress part of the saved data the client shows (career, season, quests, quest metrics)
local function progressOf(data: any)
	return { career = data.career, season = data.season, quests = data.quests, metrics = data.metrics }
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
		pinned = data.pinned,
		settings = data.settings,
		stats = data.stats,
		progress = progressOf(data),
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

	local keptPinned = {}
	for _, uid in data.pinned do
		if not removedUids[uid] then
			table.insert(keptPinned, uid)
		end
	end
	if #keptPinned ~= #data.pinned then
		data.pinned = keptPinned
		push(player, "pinned", data.pinned)
	end
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

function PlayerDataService:TransferItems(from: Player, to: Player, uids: { string }): { ItemInstance }
	local toData = dataOf(to)
	if not toData or not dataOf(from) or from == to then
		return {}
	end
	local moved = self:RemoveItems(from, uids)
	for _, item in moved do
		toData.inventory[item.uid] = item
	end
	if #moved > 0 then
		push(to, "update", moved)
		self.InventoryChanged:Fire(to)
	end
	return moved
end

function PlayerDataService:SetPinned(player: Player, uid: string, pinned: boolean)
	local data = dataOf(player)
	if not data or not data.inventory[uid] then
		return
	end
	local at = table.find(data.pinned, uid)
	if pinned == (at ~= nil) then
		return
	end
	local nextPinned = table.clone(data.pinned)
	if pinned then
		table.insert(nextPinned, uid)
	else
		table.remove(nextPinned, at :: number)
	end
	data.pinned = nextPinned
	push(player, "pinned", data.pinned)
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

function PlayerDataService:SetSetting(player: Player, id: string, value: any)
	local data = dataOf(player)
	if not data then
		return
	end
	local nextSettings = table.clone(data.settings)
	nextSettings[id] = value
	data.settings = nextSettings
	push(player, "settings", data.settings)
end

function PlayerDataService:GetSettings(player: Player): { [string]: any }
	local data = dataOf(player)
	return Settings.resolve(data and data.settings)
end

function PlayerDataService:AddStats(player: Player, amounts: { [string]: number })
	local data = dataOf(player)
	if not data then
		return
	end
	for id, amount in amounts do
		data.stats[id] = (data.stats[id] or 0) + amount
	end
	push(player, "stats", data.stats)
end

function PlayerDataService:SetStats(player: Player, values: { [string]: number })
	local data = dataOf(player)
	if not data then
		return
	end
	for id, value in values do
		data.stats[id] = value
	end
	push(player, "stats", data.stats)
end

-- cosmetics are { [kind]: { equipped = id, unlocked = { id } } }, kinds and rules live in CosmeticService
function PlayerDataService:GetCosmetics(player: Player, kind: string): { equipped: string?, unlocked: { string } }
	local data = dataOf(player)
	local entry = data and data.cosmetics and data.cosmetics[kind]
	return entry or { equipped = nil, unlocked = {} }
end

local function cosmeticEntry(data: SavedData, kind: string)
	data.cosmetics = data.cosmetics or {}
	local entry = data.cosmetics[kind]
	if not entry then
		entry = { equipped = nil, unlocked = {} }
		data.cosmetics[kind] = entry
	end
	return entry
end

function PlayerDataService:SetEquippedCosmetic(player: Player, kind: string, id: string)
	local data = dataOf(player)
	if data then
		cosmeticEntry(data, kind).equipped = id
	end
end

function PlayerDataService:UnlockCosmetic(player: Player, kind: string, id: string)
	local data = dataOf(player)
	if not data then
		return
	end
	local entry = cosmeticEntry(data, kind)
	if not table.find(entry.unlocked, id) then
		table.insert(entry.unlocked, id)
	end
end

-- saves soon, once per frame however many changes ask for it
local function requestSave(profile)
	if saveQueued[profile] then
		return
	end
	saveQueued[profile] = true
	task.defer(function()
		saveQueued[profile] = nil
		if profile:IsActive() then
			profile:Save()
		end
	end)
end

-- sends the outbox entries that are known to be saved: loaded ones, and ones queued before savedFrom (the time the
-- save that just finished started) that are also in the data that save returned (savedKeys). the second check matters
-- because OnAfterSave also fires for a save that did not write, when another server took the session over.
-- a sent entry is dropped from the data, if the profile already closed it stays saved and is sent again next
-- session (receivers ignore repeats)
local function flushOutbox(profile, savedFrom: number?, savedKeys: { [string]: boolean }?)
	for _, entry in profile.Data.tradeOutbox or {} do
		local queuedAt = outboxQueuedAt[entry.key]
		local saved = queuedAt == nil
			or (savedFrom ~= nil and queuedAt < savedFrom and savedKeys ~= nil and savedKeys[entry.key] == true)
		if saved and not outboxSending[entry.key] then
			outboxSending[entry.key] = true
			task.spawn(function()
				local ok, sent = pcall(store.MessageAsync, store, tostring(entry.to), entry.message)
				outboxSending[entry.key] = nil
				if not (ok and sent) then
					warn(`[PlayerDataService] message to {entry.to} not sent, retrying next save: {sent}`)
					return
				end
				outboxQueuedAt[entry.key] = nil
				local outbox = profile.Data.tradeOutbox
				for index, other in outbox do
					if other.key == entry.key then
						table.remove(outbox, index)
						break
					end
				end
				if entry.pump then
					PlayerDataService:Pump(entry.to)
				end
			end)
		end
	end
end

local function queueMessage(profile, to: number, message: any, pump: boolean?)
	local key = HttpService:GenerateGUID(false)
	profile.Data.tradeOutbox = profile.Data.tradeOutbox or {}
	table.insert(profile.Data.tradeOutbox, { key = key, to = to, message = message, pump = pump })
	outboxQueuedAt[key] = os.clock()
	requestSave(profile)
end

-- hooks a profile (a player's, or an offline one opened by Pump) up to the outbox and the message handler.
-- pairing the k-th finished save with the k-th oldest save start is safe whatever order saves finish in: k saves have
-- finished, so one of them started at or after that time and wrote every entry queued before it. a save that fails
-- fires no OnAfterSave, which only pairs later saves with earlier starts (sends later, never early)
local function attachMessaging(profile, player: Player?)
	local starts = {}
	profile.OnSave:Connect(function()
		table.insert(starts, os.clock())
	end)
	profile.OnAfterSave:Connect(function(lastSaved)
		local started = table.remove(starts, 1)
		if started then
			local savedKeys = {}
			for _, entry in type(lastSaved) == "table" and lastSaved.tradeOutbox or {} do
				savedKeys[entry.key] = true
			end
			flushOutbox(profile, started, savedKeys)
		end
	end)
	profile:MessageHandler(function(message, processed)
		if not messageHandler then
			return
		end
		local ctx = {
			data = profile.Data,
			player = player,
			userId = tonumber(profile.Key),
			send = function(to: number, nextMessage: any, pump: boolean?)
				queueMessage(profile, to, nextMessage, pump)
			end,
		}
		local ok, err = pcall(messageHandler, ctx, message)
		if not ok then
			warn(`[PlayerDataService] message for {profile.Key} failed, it will be retried next session: {err}`)
			return
		end
		processed()
		requestSave(profile)
	end)
	flushOutbox(profile, nil)
end

function PlayerDataService:SetMessageHandler(fn: (ctx: any, message: any) -> ())
	messageHandler = fn
end

function PlayerDataService:SendMessage(player: Player, toUserId: number, message: any, pump: boolean?)
	local profile = profiles[player]
	if profile then
		queueMessage(profile, toUserId, message, pump)
	end
end

-- handles the messages waiting on a player's profile now: saves it when they are in this server (that runs the
-- handler), otherwise opens their offline profile here for a moment. a player in another server gets their messages
-- from there (MessageAsync already asked that server to save).
function PlayerDataService:Pump(userId: number)
	if pumping[userId] then
		return
	end
	local here = Players:GetPlayerByUserId(userId)
	if here then
		if profiles[here] then
			requestSave(profiles[here])
		end
		return
	end
	pumping[userId] = true
	task.spawn(function()
		local key = tostring(userId)
		-- a player who just left still shows a session until their last save lands, so look again a few times.
		-- a player really in another server handles their messages there (MessageAsync asked that server to save)
		local ok, view
		for attempt = 1, 4 do
			ok, view = pcall(store.GetAsync, store, key)
			if not ok or not view or not view.Session or Players:GetPlayerByUserId(userId) then
				break
			end
			if attempt < 4 then
				task.wait(5)
			end
		end
		if ok and view and not view.Session and not Players:GetPlayerByUserId(userId) then
			local profile = store:StartSessionAsync(key, {
				Cancel = function()
					return Players:GetPlayerByUserId(userId) ~= nil
				end,
			})
			if profile then
				profile:Reconcile()
				local saves = 0
				profile.OnAfterSave:Connect(function()
					saves += 1
				end)
				attachMessaging(profile, nil)
				requestSave(profile)
				local deadline = os.clock() + 20
				while os.clock() < deadline and not Players:GetPlayerByUserId(userId) do
					-- sent entries leave the outbox, so an empty outbox after a save means everything went out
					if saves > 0 and #profile.Data.tradeOutbox == 0 and not saveQueued[profile] then
						break
					end
					task.wait(0.25)
				end
				profile:EndSession()
			end
		end
		pumping[userId] = nil
	end)
end

function PlayerDataService:GiveItems(player: Player, items: { ItemInstance })
	local data = dataOf(player)
	if not data or #items == 0 then
		return
	end
	for _, item in items do
		data.inventory[item.uid] = item
	end
	push(player, "update", items)
	self.InventoryChanged:Fire(player)
end

local function loadedPlayer(userId: number): Player?
	local player = Players:GetPlayerByUserId(userId)
	return if player and profiles[player] then player else nil
end

local function dropMissingEquipped(data: SavedData)
	for _, key in { "equipped", "pinned" } do
		local kept = {}
		for _, uid in (data :: any)[key] or {} do
			if data.inventory[uid] then
				table.insert(kept, uid)
			end
		end
		(data :: any)[key] = kept
	end
end

function PlayerDataService:CleanRefs(data: any)
	dropMissingEquipped(data)
end

function PlayerDataService:ViewUser(userId: number): (SavedData?, string)
	local player = loadedPlayer(userId)
	if player then
		return dataOf(player), "here"
	end
	local ok, profile = pcall(store.GetAsync, store, tostring(userId))
	if not ok then
		warn(`[PlayerDataService] could not view {userId}: {profile}`)
		return nil, "error"
	end
	if not profile then
		return nil, "none"
	end
	profile:Reconcile()
	return profile.Data, if profile.Session then "elsewhere" else "offline"
end

function PlayerDataService:EditUser(userId: number, mutate: (SavedData) -> ()): (boolean, string?)
	local player = loadedPlayer(userId)
	if player then
		local data = dataOf(player) :: SavedData
		mutate(data)
		dropMissingEquipped(data)
		push(player, "replace", {
			cash = data.cash,
			inventory = data.inventory,
			equipped = data.equipped,
			pinned = data.pinned,
			settings = data.settings,
			stats = data.stats,
			progress = progressOf(data),
		})
		self.InventoryChanged:Fire(player)
		self.EquippedChanged:Fire(player, data.equipped)
		return true
	end

	local ok, profile = pcall(store.GetAsync, store, tostring(userId))
	if not ok then
		return false, "Datastore error, try again"
	end
	if not profile then
		return false, "No saved data for that user"
	end
	if profile.Session then
		return false, "That player is in another server, edit them there or after they leave"
	end
	profile:Reconcile()
	mutate(profile.Data)
	dropMissingEquipped(profile.Data)
	local saved, err = pcall(profile.SetAsync, profile)
	if not saved then
		return false, `Save failed: {err}`
	end
	return true
end

function PlayerDataService:GetData(player: Player): any
	return dataOf(player)
end

function PlayerDataService:Push(player: Player, kind: string, payload: any)
	push(player, kind, payload)
end

function PlayerDataService:GetDaily(player: Player, today: number): { day: number, hiloEarned: number }?
	local data = dataOf(player)
	if not data then
		return nil
	end
	if not data.daily or data.daily.day ~= today then
		data.daily = { day = today, hiloEarned = 0 }
	end
	return data.daily
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
	push(player, "replace", {
		cash = data.cash,
		inventory = data.inventory,
		equipped = data.equipped,
		pinned = data.pinned,
		settings = data.settings,
		stats = data.stats,
		progress = progressOf(data),
	})
	self.InventoryChanged:Fire(player)
	if hadEquipped then
		self.EquippedChanged:Fire(player, data.equipped)
	end
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	-- an offline profile this server opened for trade messages has to close before the player's session starts
	while pumping[player.UserId] and player.Parent == Players do
		task.wait(0.25)
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
	attachMessaging(profile, player)
	PlayerDataService.Loaded:Fire(player)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		PlayerDataService.Leaving:Fire(player)
	end
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
