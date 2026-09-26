-- creates brand new item instances with rolled condition, trait and a global serial.
-- used by CaseService now and meant to be reused by anything else that grants items (battles, upgrader, rewards).
-- api: ItemFactory.roll(caseId, luck?) -> assetId (instant),
-- ItemFactory.create(assetId, caseId?, luck?, owner?) -> ItemInstance (yields for the serial, owner is the player
-- recorded as the original owner), ItemFactory.fromCase(caseId, luck?, owner?) -> ItemInstance (yields, roll + create)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Condition = require(Shared.Modifiers.Condition)
local StatTracker = require(Shared.Modifiers.StatTracker)
local Traits = require(Shared.Modifiers.Traits)
local Types = require(Shared.Types)
local SerialService = require(ServerScriptService.Server.Services.SerialService)

local rng = Random.new()

local ItemFactory = {}

function ItemFactory.roll(caseId: string, luck: number?): number
	return CaseRegistry.roll(caseId, rng, luck)
end

function ItemFactory.create(assetId: number, caseId: string?, luck: number?, owner: Player?): Types.ItemInstance
	local traits = Traits.rollAll(rng, luck)
	return {
		uid = HttpService:GenerateGUID(false),
		assetId = assetId,
		float = Condition.rollFloat(rng),
		trait = traits[1],
		traits = if #traits > 0 then traits else nil,
		serial = SerialService:Next(assetId),
		caseId = caseId,
		obtainedAt = os.time(),
		series = CaseRegistry.seriesFor(caseId, assetId),
		originalOwner = if owner then { userId = owner.UserId, name = owner.Name } else nil,
		tracker = StatTracker.roll(rng),
	}
end

function ItemFactory.fromCase(caseId: string, luck: number?, owner: Player?): Types.ItemInstance
	return ItemFactory.create(ItemFactory.roll(caseId, luck), caseId, luck, owner)
end

return ItemFactory
