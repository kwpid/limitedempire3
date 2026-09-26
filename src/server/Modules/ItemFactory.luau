-- creates brand new item instances with rolled condition, trait and a global serial.
-- used by CaseService now and meant to be reused by anything else that grants items (battles, upgrader, rewards).
-- api: ItemFactory.roll(caseId, luck?) -> assetId (instant), ItemFactory.create(assetId, caseId?, luck?) -> ItemInstance
-- (yields for the serial), ItemFactory.fromCase(caseId, luck?) -> ItemInstance (yields, roll + create)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Condition = require(Shared.Modifiers.Condition)
local Traits = require(Shared.Modifiers.Traits)
local Types = require(Shared.Types)
local SerialService = require(ServerScriptService.Server.Services.SerialService)

local rng = Random.new()

local ItemFactory = {}

function ItemFactory.roll(caseId: string, luck: number?): number
	return CaseRegistry.roll(caseId, rng, luck)
end

function ItemFactory.create(assetId: number, caseId: string?, luck: number?): Types.ItemInstance
	return {
		uid = HttpService:GenerateGUID(false),
		assetId = assetId,
		float = Condition.rollFloat(rng),
		trait = Traits.roll(rng, luck),
		serial = SerialService:Next(assetId),
		caseId = caseId,
		obtainedAt = os.time(),
	}
end

function ItemFactory.fromCase(caseId: string, luck: number?): Types.ItemInstance
	return ItemFactory.create(ItemFactory.roll(caseId, luck), caseId, luck)
end

return ItemFactory
