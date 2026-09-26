-- trading between any two players, in the same server, another server or offline, like Roblox trades.
-- each player keeps their own copy of a trade in their saved data (data.trades[id], Types.Trade), and the two copies
-- are kept in step with profile messages (PlayerDataService:SendMessage). messages are durable and can arrive twice,
-- so every handler below only acts when the trade is in the state it expects.
--
-- flow: the sender saves an outbound pending trade and messages "offer" to the receiver, who gets an inbound copy.
-- accept: the receiver's items leave their inventory into the trade's escrow (status processing) and "accept" goes
-- to the sender with those items. the sender's side checks it still owns its items, swaps them and replies
-- "complete" with its items, or "refund" when it can't, which gives the receiver their escrow back. an item is only
-- ever in one place: an inventory, an escrow or a message on its way.
-- decline / cancel / counter move both copies out of pending. a counter is a decline plus a new trade back.
-- items stay in the sender's inventory while a trade is pending (like Roblox), so a trade whose items are gone by
-- the time it is accepted goes inactive. pending trades expire after Config.Trade.ExpireDays.
-- anti-scam: a trade only goes through with the exact items both players saw. items are matched by uid and by
-- fingerprint (item, float, serial, traits, stat tracker), so an item that changed since the trade was sent fails
-- the trade instead of swapping in something else.
-- players can turn off trade requests (the allowTrades setting): sending to them is refused up front, and an offer
-- that arrives after they turned it off is declined as "closed".
-- leaving: every step lives in saved data and messages, so either player can leave (or a server can crash) at any
-- point. an accept is finished by the sender's server, or by this server opening their profile when they are
-- offline, and the receiver gets their side when they are next loaded.
--
-- client: Net.functions.TradeAction(action, payload) -> Result. actions: list, lookup { name } -> { userId, name },
-- inventory { userId } -> { name, items }, send { userId, give, get }, accept { id }, decline { id }, cancel { id },
-- counter { id, give, get } (give / get are item uids, give is what the caller gives).
-- Net.events.TradeUpdate(trades, note?) sends the player's full trade list whenever it changes, note is
-- { text, kind = "info" | "good" | "bad" } for a toast.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Settings = require(Shared.Settings)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Trade = Types.Trade
type ItemInstance = Types.ItemInstance
type Note = { text: string, kind: string }

local TradeService = {}

local TRADE = Config.Trade
local EXPIRE_SECONDS = TRADE.ExpireDays * 86400
local INVENTORY_CACHE_SECONDS = 15
local MAX_NAME_LENGTH = 20
-- lookups hit Roblox web apis and datastore reads, so each gets a longer cooldown of its own
local LOOKUP_COOLDOWN = 2
local LOOKUPS = { lookup = true, inventory = true }
-- sending writes to the other player's datastore key, so sends get a cooldown of their own
local SEND_COOLDOWN = 3
local SENDS = { send = true, counter = true }
local HISTORY = { completed = true, declined = true, countered = true, cancelled = true, inactive = true }

local lastAction: { [Player]: number } = {}
local lastLookup: { [Player]: { [string]: number } } = {}
local lastSend: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local inventoryCache: {
	[number]: { at: number, name: string, inventory: { [string]: ItemInstance }, allowTrades: boolean },
} = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function tradesOf(data): { [string]: Trade }
	data.trades = data.trades or {}
	return data.trades
end

local function setStatus(trade: Trade, status: string, note: string?)
	trade.status = status
	trade.note = note
	trade.updatedAt = os.time()
end

local function uidsOf(items: { ItemInstance }): { string }
	local uids = {}
	for _, item in items do
		table.insert(uids, item.uid)
	end
	return uids
end

-- what makes an item the item: the same uid can't hold a different item, but this also catches an item that was
-- changed after the trade was sent (the stat tracker count can grow, only having one counts)
local function fingerprint(item: ItemInstance): string
	local traits = table.clone(item.traits or (if item.trait then { item.trait } else {}))
	table.sort(traits)
	-- floats go through datastore / message json, so they are compared to 10 places (the ui shows 6)
	local float = string.format("%.10f", tonumber(item.float) or -1)
	return `{item.assetId}|{float}|{item.serial}|{table.concat(traits, ",")}|{item.tracker ~= nil}`
end

-- true when the inventory holds every listed item, unchanged from the listed copy
local function owns(inventory, items: { ItemInstance }): boolean
	for _, item in items do
		local held = inventory[item.uid]
		if not held or fingerprint(held) ~= fingerprint(item) then
			return false
		end
	end
	return true
end

-- true when both lists are the same items (order aside)
local function sameItems(a: { ItemInstance }, b: { ItemInstance }): boolean
	if #a ~= #b then
		return false
	end
	local byUid = {}
	for _, item in a do
		byUid[item.uid] = fingerprint(item)
	end
	for _, item in b do
		if byUid[item.uid] ~= fingerprint(item) then
			return false
		end
		byUid[item.uid] = nil
	end
	return next(byUid) == nil
end

local function validUserId(userId: any): boolean
	return type(userId) == "number" and userId > 0 and userId % 1 == 0 and userId < 2 ^ 53
end

-- copies of the listed items, nil if any is missing
local function pick(inventory, uids: { string }): { ItemInstance }?
	local items = {}
	for _, uid in uids do
		local item = inventory[uid]
		if not item then
			return nil
		end
		table.insert(items, deepCopy(item))
	end
	return items
end

local function validItems(items: any): boolean
	if type(items) ~= "table" or #items > TRADE.MaxItems then
		return false
	end
	for _, item in items do
		if type(item) ~= "table" or type(item.uid) ~= "string" or type(item.assetId) ~= "number" then
			return false
		end
	end
	return true
end

-- takes the exact item records out of the inventory (a loaded player's, pushing the change to them, or offline data)
local function takeItems(ctx, uids: { string }): { ItemInstance }
	if ctx.player then
		return PlayerDataService:RemoveItems(ctx.player, uids)
	end
	local removed = {}
	for _, uid in uids do
		local item = ctx.data.inventory[uid]
		if item then
			ctx.data.inventory[uid] = nil
			table.insert(removed, item)
		end
	end
	PlayerDataService:CleanRefs(ctx.data)
	return removed
end

local function addStat(ctx, id: string)
	if ctx.player then
		PlayerDataService:AddStats(ctx.player, { [id] = 1 })
	else
		ctx.data.stats = ctx.data.stats or {}
		ctx.data.stats[id] = (ctx.data.stats[id] or 0) + 1
	end
end

local function giveItems(ctx, items: { ItemInstance })
	if ctx.player then
		PlayerDataService:GiveItems(ctx.player, items)
		return
	end
	for _, item in items do
		ctx.data.inventory[item.uid] = item
	end
end

-- pending trades past their expiry go inactive
local function expire(data)
	local now = os.time()
	for _, trade in tradesOf(data) do
		if trade.status == "pending" and now - trade.createdAt > EXPIRE_SECONDS then
			setStatus(trade, "inactive", "Expired")
		end
	end
end

-- keeps the saved list in bounds: the oldest received trades past MaxInbound go inactive, and only the newest
-- KeepHistory completed and KeepHistory inactive trades are kept. pending and processing trades are never dropped.
local function prune(data)
	local trades = tradesOf(data)
	local completed, inactive, inbound = {}, {}, {}
	for _, trade in trades do
		if trade.status == "completed" then
			table.insert(completed, trade)
		elseif HISTORY[trade.status] then
			table.insert(inactive, trade)
		elseif trade.status == "pending" and trade.direction == "inbound" then
			table.insert(inbound, trade)
		end
	end
	table.sort(inbound, function(a, b)
		return a.createdAt > b.createdAt
	end)
	for index = TRADE.MaxInbound + 1, #inbound do
		setStatus(inbound[index], "inactive", "Too many trades waiting")
		table.insert(inactive, inbound[index])
	end
	for _, group in { completed, inactive } do
		table.sort(group, function(a, b)
			return a.updatedAt > b.updatedAt
		end)
		for index = TRADE.KeepHistory + 1, #group do
			trades[group[index].id] = nil
		end
	end
end

-- the list the client sees (escrow stays on the server)
local function listOf(data): { Trade }
	expire(data)
	prune(data)
	local list = {}
	for _, trade in tradesOf(data) do
		local copy = table.clone(trade)
		copy.escrow = nil
		table.insert(list, copy)
	end
	return list
end

local function notify(ctx, note: Note?)
	if ctx.player and ctx.player.Parent == Players then
		Net.events.TradeUpdate:FireClient(ctx.player, listOf(ctx.data), note)
	end
end

local function contextOf(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	return {
		data = data,
		player = player,
		userId = player.UserId,
		send = function(to: number, message: any, pump: boolean?)
			PlayerDataService:SendMessage(player, to, message, pump)
		end,
	}
end

-- another player's inventory: live when they are in this server, otherwise their saved data (cached for a moment).
-- returns inventory?, name?, err?, allowTrades
local function inventoryOf(userId: number): ({ [string]: ItemInstance }?, string?, string?, boolean)
	local here = Players:GetPlayerByUserId(userId)
	local hereData = here and PlayerDataService:GetData(here)
	if here and hereData then
		return hereData.inventory, here.Name, nil, PlayerDataService:GetSettings(here).allowTrades ~= false
	end
	local cached = inventoryCache[userId]
	if cached and os.clock() - cached.at < INVENTORY_CACHE_SECONDS then
		return cached.inventory, cached.name, nil, cached.allowTrades
	end
	local data, where = PlayerDataService:ViewUser(userId)
	if where == "none" then
		return nil, nil, "That player has never played", false
	elseif not data then
		return nil, nil, "Couldn't load their inventory, try again", false
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local entry = {
		at = os.clock(),
		name = if ok then name else tostring(userId),
		inventory = data.inventory,
		allowTrades = Settings.resolve(data.settings).allowTrades ~= false,
	}
	inventoryCache[userId] = entry
	return entry.inventory, entry.name, nil, entry.allowTrades
end

-- a clean list of up to MaxItems unique uids, nil if the list is malformed
local function cleanUids(list: any): { string }?
	if type(list) ~= "table" then
		return nil
	end
	local clean, seen, count = {}, {}, 0
	for _, uid in list do
		count += 1
		if type(uid) ~= "string" or #uid > 64 or seen[uid] then
			return nil
		end
		seen[uid] = true
		table.insert(clean, uid)
	end
	if count ~= #list or #clean > TRADE.MaxItems then
		return nil
	end
	return clean
end

local function createTrade(ctx, targetId: number, giveUids: { string }, getUids: { string }): (Trade?, string?)
	if targetId == ctx.userId then
		return nil, "You can't trade with yourself"
	elseif #giveUids + #getUids == 0 then
		return nil, "Add at least one item"
	end
	local waiting = 0
	for _, trade in tradesOf(ctx.data) do
		if trade.direction == "outbound" and trade.status == "pending" then
			waiting += 1
		end
	end
	if waiting >= TRADE.MaxOutbound then
		return nil, `You can only have {TRADE.MaxOutbound} trades waiting at once`
	end

	local theirs, name, err, allowTrades = inventoryOf(targetId)
	if not theirs then
		return nil, err
	elseif not allowTrades then
		return nil, `{name} isn't accepting trades`
	end
	-- the lookup can yield, so the player's own items are checked after it (and on the data they have now, in case
	-- they left and came back meanwhile)
	if PlayerDataService:GetData(ctx.player) ~= ctx.data then
		return nil, "Your data isn't loaded"
	end
	local give = pick(ctx.data.inventory, giveUids)
	if not give then
		return nil, "You don't own some of those items anymore"
	end
	local get = pick(theirs, getUids)
	if not get then
		return nil, `{name} doesn't own some of those items anymore`
	end

	local now = os.time()
	local trade: Trade = {
		id = HttpService:GenerateGUID(false),
		direction = "outbound",
		partnerId = targetId,
		partnerName = name :: string,
		status = "pending",
		give = give,
		get = get,
		createdAt = now,
		updatedAt = now,
	}
	tradesOf(ctx.data)[trade.id] = trade
	ctx.send(targetId, {
		t = "offer",
		id = trade.id,
		fromId = ctx.userId,
		fromName = ctx.player.Name,
		give = deepCopy(give),
		get = deepCopy(get),
		createdAt = now,
	})
	return trade
end

local function findTrade(ctx, id: any, direction: string): (Trade?, string?)
	local trade = type(id) == "string" and tradesOf(ctx.data)[id]
	if not trade or trade.direction ~= direction then
		return nil, "Trade not found"
	end
	expire(ctx.data)
	if trade.status ~= "pending" then
		return nil, "This trade is no longer active"
	end
	return trade
end

local actions = {}

function actions.send(ctx, payload): Types.Result<nil>
	local give, get = cleanUids(payload.give), cleanUids(payload.get)
	if not validUserId(payload.userId) or not give or not get then
		return { ok = false, err = "Invalid trade" }
	end
	local _, err = createTrade(ctx, payload.userId, give, get)
	if err then
		return { ok = false, err = err }
	end
	notify(ctx)
	return { ok = true }
end

function actions.accept(ctx, payload): Types.Result<nil>
	local trade, err = findTrade(ctx, payload.id, "inbound")
	if not trade then
		return { ok = false, err = err }
	end
	local uids = uidsOf(trade.give)
	if not owns(ctx.data.inventory, trade.give) then
		setStatus(trade, "inactive", "You no longer had all of your items")
		ctx.send(trade.partnerId, { t = "decline", id = trade.id, fromId = ctx.userId, reason = "inactive" })
		notify(ctx)
		return { ok = false, err = "You no longer have all of your items, the trade is now inactive" }
	end
	local escrow = takeItems(ctx, uids)
	if #escrow ~= #uids then
		-- can't happen after the check above, but never leave items half taken
		giveItems(ctx, escrow)
		return { ok = false, err = "Something went wrong, try again" }
	end
	trade.escrow = escrow
	setStatus(trade, "processing")
	ctx.send(trade.partnerId, { t = "accept", id = trade.id, fromId = ctx.userId, items = deepCopy(escrow) }, true)
	notify(ctx)
	return { ok = true }
end

function actions.decline(ctx, payload): Types.Result<nil>
	local trade, err = findTrade(ctx, payload.id, "inbound")
	if not trade then
		return { ok = false, err = err }
	end
	setStatus(trade, "declined")
	ctx.send(trade.partnerId, { t = "decline", id = trade.id, fromId = ctx.userId })
	notify(ctx)
	return { ok = true }
end

function actions.cancel(ctx, payload): Types.Result<nil>
	local trade, err = findTrade(ctx, payload.id, "outbound")
	if not trade then
		return { ok = false, err = err }
	end
	setStatus(trade, "cancelled")
	ctx.send(trade.partnerId, { t = "cancel", id = trade.id, fromId = ctx.userId })
	notify(ctx)
	return { ok = true }
end

function actions.counter(ctx, payload): Types.Result<nil>
	local original, err = findTrade(ctx, payload.id, "inbound")
	if not original then
		return { ok = false, err = err }
	end
	local give, get = cleanUids(payload.give), cleanUids(payload.get)
	if not give or not get then
		return { ok = false, err = "Invalid trade" }
	end
	local _, createErr = createTrade(ctx, original.partnerId, give, get)
	if createErr then
		return { ok = false, err = createErr }
	end
	-- the new trade already went out, the original is only closed if nothing changed it in the meantime
	if original.status == "pending" then
		setStatus(original, "countered")
		ctx.send(original.partnerId, { t = "decline", id = original.id, fromId = ctx.userId, reason = "countered" })
	end
	notify(ctx)
	return { ok = true }
end

function actions.list(ctx): Types.Result<{ Trade }>
	return { ok = true, data = listOf(ctx.data) }
end

function actions.lookup(_ctx, payload): Types.Result<any>
	local name = payload.name
	if type(name) ~= "string" or #name < 3 or #name > MAX_NAME_LENGTH or not string.match(name, "^[%w_]+$") then
		return { ok = false, err = "Enter a valid username" }
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, name)
	if not ok or type(userId) ~= "number" then
		return { ok = false, err = "No player with that username" }
	end
	local okName, realName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return { ok = true, data = { userId = userId, name = if okName then realName else name } }
end

function actions.inventory(ctx, payload): Types.Result<any>
	local userId = payload.userId
	if not validUserId(userId) or userId == ctx.userId then
		return { ok = false, err = "Invalid player" }
	end
	local inventory, name, err = inventoryOf(userId)
	if not inventory then
		return { ok = false, err = err }
	end
	local items = {}
	for _, item in inventory do
		table.insert(items, item)
	end
	return { ok = true, data = { name = name, items = items } }
end

-- profile messages from the other side of a trade (see the flow at the top)
local function handleMessage(ctx, message: any)
	if type(message) ~= "table" or type(message.id) ~= "string" or not validUserId(message.fromId) then
		return
	end
	if message.fromId == ctx.userId then
		return
	end
	local trades = tradesOf(ctx.data)
	local trade = trades[message.id]
	local kind = message.t
	local note: Note? = nil

	if kind == "offer" then
		local fresh = type(message.createdAt) == "number" and os.time() - message.createdAt <= EXPIRE_SECONDS
		if trade or not fresh or not validItems(message.give) or not validItems(message.get) then
			return
		end
		if Settings.resolve(ctx.data.settings).allowTrades == false then
			ctx.send(message.fromId, { t = "decline", id = message.id, fromId = ctx.userId, reason = "closed" })
			return
		end
		local name = if type(message.fromName) == "string" then message.fromName else tostring(message.fromId)
		trades[message.id] = {
			id = message.id,
			direction = "inbound",
			partnerId = message.fromId,
			partnerName = name,
			status = "pending",
			give = message.get,
			get = message.give,
			createdAt = message.createdAt,
			updatedAt = os.time(),
		}
		note = { text = `New trade from {name}`, kind = "info" }
	elseif kind == "decline" then
		if not trade or trade.direction ~= "outbound" or trade.status ~= "pending" or trade.partnerId ~= message.fromId then
			return
		end
		if message.reason == "countered" then
			setStatus(trade, "countered")
			note = { text = `{trade.partnerName} countered your trade`, kind = "info" }
		elseif message.reason == "inactive" then
			setStatus(trade, "inactive", `{trade.partnerName} no longer had their items`)
		elseif message.reason == "closed" then
			setStatus(trade, "inactive", `{trade.partnerName} isn't accepting trades`)
			note = { text = `{trade.partnerName} isn't accepting trades`, kind = "bad" }
		else
			setStatus(trade, "declined")
			note = { text = `{trade.partnerName} declined your trade`, kind = "bad" }
		end
	elseif kind == "cancel" then
		if not trade or trade.direction ~= "inbound" or trade.status ~= "pending" or trade.partnerId ~= message.fromId then
			return
		end
		setStatus(trade, "cancelled")
	elseif kind == "accept" then
		if trade and trade.status == "completed" then
			return -- a repeat of an accept that already went through
		end
		local reason = nil
		if not trade or trade.direction ~= "outbound" then
			reason = "The trade no longer exists"
		elseif trade.status ~= "pending" then
			reason = `The trade was already {trade.status}`
		elseif trade.partnerId ~= message.fromId or not validItems(message.items) then
			reason = "The trade was invalid"
		elseif not sameItems(message.items, trade.get) then
			-- the receiver's items aren't the ones this trade asked for
			reason = "The items didn't match the trade"
			setStatus(trade, "inactive", "The other player's items didn't match the trade")
		elseif not owns(ctx.data.inventory, trade.give) then
			reason = "The other player no longer had all of their items"
			setStatus(trade, "inactive", "You no longer had all of your items")
		end
		if reason then
			ctx.send(message.fromId, { t = "refund", id = message.id, fromId = ctx.userId, reason = reason })
		else
			local moved = takeItems(ctx, uidsOf((trade :: Trade).give))
			giveItems(ctx, message.items)
			local done = trade :: Trade
			done.give = deepCopy(moved)
			done.get = deepCopy(message.items)
			setStatus(done, "completed")
			addStat(ctx, "tradesCompleted")
			ctx.send(message.fromId, { t = "complete", id = message.id, fromId = ctx.userId, items = deepCopy(moved) })
			note = { text = `{done.partnerName} accepted your trade`, kind = "good" }
		end
	elseif kind == "complete" then
		if not trade or trade.direction ~= "inbound" or trade.status ~= "processing" then
			return
		elseif trade.partnerId ~= message.fromId or not validItems(message.items) then
			return
		end
		giveItems(ctx, message.items)
		trade.get = deepCopy(message.items)
		trade.escrow = nil
		setStatus(trade, "completed")
		addStat(ctx, "tradesCompleted")
		note = { text = `Trade with {trade.partnerName} completed`, kind = "good" }
	elseif kind == "refund" then
		if not trade or trade.direction ~= "inbound" or trade.status ~= "processing" then
			return
		elseif trade.partnerId ~= message.fromId then
			return
		end
		giveItems(ctx, trade.escrow or {})
		trade.escrow = nil
		local reason = if type(message.reason) == "string" then message.reason else "It couldn't go through"
		setStatus(trade, "inactive", reason)
		note = { text = `Trade with {trade.partnerName} failed, your items were returned`, kind = "bad" }
	else
		return
	end

	prune(ctx.data)
	notify(ctx, note)
end

function TradeService:Init()
	PlayerDataService:SetMessageHandler(handleMessage)

	Net.functions.TradeAction.OnServerInvoke = function(player: Player, action: any, payload: any)
		local handler = type(action) == "string" and actions[action]
		if not handler then
			return { ok = false, err = "Invalid request" }
		end
		local now = os.clock()
		local changes = not LOOKUPS[action] and action ~= "list"
		if changes and lastAction[player] and now - lastAction[player] < TRADE.ActionCooldown then
			return { ok = false, err = "Slow down a little" }
		elseif LOOKUPS[action] and now - ((lastLookup[player] or {})[action] or -math.huge) < LOOKUP_COOLDOWN then
			return { ok = false, err = "Slow down a little" }
		elseif SENDS[action] and lastSend[player] and now - lastSend[player] < SEND_COOLDOWN then
			return { ok = false, err = "Wait a moment before sending another trade" }
		end
		if busy[player] then
			return { ok = false, err = "Still working on your last request" }
		end
		local ctx = contextOf(player)
		if not ctx then
			return { ok = false, err = "Your data is still loading" }
		end
		if changes then
			lastAction[player] = now
		end
		if LOOKUPS[action] then
			lastLookup[player] = lastLookup[player] or {}
			lastLookup[player][action] = now
		end
		busy[player] = true
		local ok, result = pcall(handler, ctx, if type(payload) == "table" then payload else {})
		busy[player] = nil
		if ok and SENDS[action] and result.ok then
			lastSend[player] = os.clock()
		end
		if not ok then
			warn(`[TradeService] {action} failed for {player.Name}: {result}`)
			return { ok = false, err = "Something went wrong, try again" }
		end
		return result
	end

	PlayerDataService.Loaded:Connect(function(player: Player)
		local ctx = contextOf(player)
		if ctx then
			notify(ctx)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastAction[player] = nil
		lastLookup[player] = nil
		lastSend[player] = nil
		busy[player] = nil
	end)
end

return TradeService
