-- creates brand new item instances with rolled condition, trait and a global serial.
-- used by CaseService now and meant to be reused by anything else that grants items (battles, upgrader, rewards).
-- api: ItemFactory.roll(caseId, luck?) -> assetId (instant),
-- ItemFactory.rollTier(caseId, tierId, luck?) -> assetId (a normal roll if the case has nothing of that tier),
-- ItemFactory.create(assetId, caseId?, luck?, owner?, override?) -> ItemInstance (yields for the serial, owner is
-- the player recorded as the original owner), ItemFactory.fromCase(caseId, luck?, owner?) -> ItemInstance
-- override (admin testing, see AdminService): { traits = { id }?, tracker = true?, condition = band id? }

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

function ItemFactory.rollTier(caseId: string, tierId: string, luck: number?): number
	return CaseRegistry.rollTier(caseId, tierId, rng) or ItemFactory.roll(caseId, luck)
end

local function floatIn(bandId: string): number?
	for _, band in Condition.list do
		if band.id == bandId then
			return band.min + rng:NextNumber() * (band.max - band.min) * 0.999
		end
	end
	return nil
end

function ItemFactory.create(assetId: number, caseId: string?, luck: number?, owner: Player?, override: any?): Types.ItemInstance
	local traits = if override and override.traits then Traits.of({ traits = override.traits }) else Traits.rollAll(rng, luck)
	local float = override and override.condition and floatIn(override.condition) or Condition.rollFloat(rng, luck)
	local tracker = if override and override.tracker then { opens = 0 } else StatTracker.roll(rng)
	return {
		uid = HttpService:GenerateGUID(false),
		assetId = assetId,
		float = math.floor(float * 1e6) / 1e6,
		trait = traits[1],
		traits = if #traits > 0 then traits else nil,
		serial = SerialService:Next(assetId),
		caseId = caseId,
		obtainedAt = os.time(),
		series = CaseRegistry.seriesFor(caseId, assetId),
		originalOwner = if owner then { userId = owner.UserId, name = owner.Name } else nil,
		tracker = tracker,
	}
end

function ItemFactory.fromCase(caseId: string, luck: number?, owner: Player?): Types.ItemInstance
	return ItemFactory.create(ItemFactory.roll(caseId, luck), caseId, luck, owner)
end

return ItemFactory
