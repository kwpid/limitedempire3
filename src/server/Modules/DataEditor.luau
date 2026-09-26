-- admin data editor: view and fix any player's saved data by user id, online in this server or offline.
-- every function checks its input, applies the change through PlayerDataService:EditUser (live or saved profile)
-- and returns a fresh snapshot of the player so the admin panel can redraw.
-- AdminService exposes these as the "data*" admin actions.
--
-- api: DataEditor.snapshot(userId) -> Result<Snapshot>, DataEditor.addItems(userId, payload),
-- DataEditor.editItem(userId, uid, payload), DataEditor.removeItems(userId, uids), DataEditor.setCash(userId, amount),
-- DataEditor.setCosmetic(userId, kind, id, unlocked) -> Result<Snapshot>

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local ItemRegistry = require(Shared.Items.ItemRegistry)
local NameStyles = require(Shared.Visuals.NameStyles)
local Titles = require(Shared.Titles)
local Traits = require(Shared.Modifiers.Traits)
local Types = require(Shared.Types)
local Valuation = require(Shared.Modifiers.Valuation)
local ItemFactory = require(ServerScriptService.Server.Modules.ItemFactory)
local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService)

local MAX_SPAWN = 50
local MAX_CASH = 1e15
local COSMETIC_LISTS = { title = Titles.list, nameStyle = NameStyles.list }

export type Snapshot = {
	userId: number,
	name: string,
	where: string,
	cash: number,
	inventory: { Types.ItemInstance },
	equipped: { string },
	cosmetics: any,
	stats: { [string]: number },
}

local DataEditor = {}

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else `User {userId}`
	return names[userId]
end

local function fail(err: string): Types.Result<any>
	return { ok = false, err = err }
end

local function readUserId(value: any): number?
	if type(value) ~= "number" or value ~= math.floor(value) or value < 1 then
		return nil
	end
	return value
end

-- traits must be known ids, at most two, stored best first
local function readTraits(value: any): ({ string }?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "table" or #value > 2 then
		return nil, "Pick up to 2 traits"
	end
	for _, id in value do
		if not Traits.get(id) then
			return nil, "Unknown trait"
		end
	end
	return Traits.of({ traits = value }), nil
end

local function readFloat(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "number" or value ~= value or value < 0 or value >= 1 then
		return nil, "Float must be from 0 up to (not including) 1"
	end
	return math.floor(value * 1e6) / 1e6, nil
end

local function readSerial(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "number" or value ~= math.floor(value) or value < 1 then
		return nil, "Serial must be a whole number, 1 or higher"
	end
	return value, nil
end

local function applyTraits(item: Types.ItemInstance, traits: { string })
	item.trait = traits[1]
	item.traits = if #traits > 0 then traits else nil
end

function DataEditor.snapshot(userId: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	if not id then
		return fail("Enter a valid user id")
	end
	local data, where = PlayerDataService:ViewUser(id)
	if not data then
		return fail(if where == "none" then "That user has no saved data" else "Datastore error, try again")
	end
	local inventory = {}
	for _, item in data.inventory do
		table.insert(inventory, item)
	end
	table.sort(inventory, function(a, b)
		local av, bv = Valuation.value(a), Valuation.value(b)
		if av == bv then
			return a.uid < b.uid
		end
		return av > bv
	end)
	return {
		ok = true,
		data = {
			userId = id,
			name = nameOf(id),
			where = where,
			cash = data.cash,
			inventory = inventory,
			equipped = data.equipped,
			cosmetics = data.cosmetics,
			stats = data.stats,
		},
	}
end

local function editThen(userId: number, mutate: (any) -> ()): Types.Result<Snapshot>
	local ok, err = PlayerDataService:EditUser(userId, mutate)
	if not ok then
		return fail(err or "Edit failed")
	end
	return DataEditor.snapshot(userId)
end

-- payload: { assetId, count?, traits?, float?, serial?, tracker? (boolean) }. unset float and serial roll as
-- normal (the serial takes the next global number), unset traits means none.
function DataEditor.addItems(userId: any, payload: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	if not id or type(payload) ~= "table" then
		return fail("Invalid request")
	end
	local assetId = tonumber(payload.assetId)
	if not assetId or not ItemRegistry.get(assetId) then
		return fail("Unknown asset id, it must be in ItemData or CustomItems")
	end
	local count = payload.count or 1
	if type(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > MAX_SPAWN then
		return fail(`Count must be 1 to {MAX_SPAWN}`)
	end
	local traits, traitErr = readTraits(payload.traits)
	local float, floatErr = readFloat(payload.float)
	local serial, serialErr = readSerial(payload.serial)
	if traitErr or floatErr or serialErr then
		return fail(traitErr or floatErr or serialErr :: string)
	end

	local owner = { userId = id, name = nameOf(id) }
	local items = {}
	for _ = 1, count do
		local item = ItemFactory.create(assetId, nil, 1, nil, {
			traits = traits or {},
			float = float,
			serial = serial,
			tracker = payload.tracker == true,
		})
		item.originalOwner = owner
		table.insert(items, item)
	end
	return editThen(id, function(data)
		for _, item in items do
			data.inventory[item.uid] = item
		end
	end)
end

-- payload: { traits?, float?, serial?, tracker? (false removes it, a number sets the count) }, unset fields are kept
function DataEditor.editItem(userId: any, uid: any, payload: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	if not id or type(uid) ~= "string" or type(payload) ~= "table" then
		return fail("Invalid request")
	end
	local traits, traitErr = readTraits(payload.traits)
	local float, floatErr = readFloat(payload.float)
	local serial, serialErr = readSerial(payload.serial)
	if traitErr or floatErr or serialErr then
		return fail(traitErr or floatErr or serialErr :: string)
	end
	local tracker = payload.tracker
	if
		tracker ~= nil
		and tracker ~= false
		and (type(tracker) ~= "number" or tracker < 0 or tracker ~= math.floor(tracker))
	then
		return fail("Tracker count must be a whole number, 0 or higher")
	end

	local found = false
	local result = editThen(id, function(data)
		local item = data.inventory[uid]
		if not item then
			return
		end
		found = true
		if traits then
			applyTraits(item, traits)
		end
		if float then
			item.float = float
		end
		if serial then
			item.serial = serial
		end
		if tracker == false then
			item.tracker = nil
		elseif type(tracker) == "number" then
			item.tracker = { opens = tracker }
		end
	end)
	if result.ok and not found then
		return fail("That item is no longer in their inventory")
	end
	return result
end

function DataEditor.removeItems(userId: any, uids: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	if not id or type(uids) ~= "table" or #uids == 0 then
		return fail("Invalid request")
	end
	for _, uid in uids do
		if type(uid) ~= "string" then
			return fail("Invalid request")
		end
	end
	return editThen(id, function(data)
		for _, uid in uids do
			data.inventory[uid] = nil
		end
	end)
end

function DataEditor.setCash(userId: any, amount: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	if not id or type(amount) ~= "number" or amount ~= amount or amount < 0 or amount > MAX_CASH then
		return fail("Invalid amount")
	end
	return editThen(id, function(data)
		data.cash = math.floor(amount)
	end)
end

function DataEditor.setCosmetic(userId: any, kind: any, cosmeticId: any, unlocked: any): Types.Result<Snapshot>
	local id = readUserId(userId)
	local list = type(kind) == "string" and COSMETIC_LISTS[kind]
	if not id or not list or type(unlocked) ~= "boolean" then
		return fail("Invalid request")
	end
	local exists = false
	for _, entry in list do
		exists = exists or entry.id == cosmeticId
	end
	if not exists then
		return fail("Unknown cosmetic")
	end
	return editThen(id, function(data)
		data.cosmetics = data.cosmetics or {}
		local entry = data.cosmetics[kind] or { equipped = nil, unlocked = {} }
		data.cosmetics[kind] = entry
		local at = table.find(entry.unlocked, cosmeticId)
		if unlocked and not at then
			table.insert(entry.unlocked, cosmeticId)
		elseif not unlocked and at then
			table.remove(entry.unlocked, at)
			if entry.equipped == cosmeticId then
				entry.equipped = nil
			end
		end
	end)
end

return DataEditor
