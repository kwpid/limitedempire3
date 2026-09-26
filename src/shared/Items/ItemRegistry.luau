-- read-only lookup over the generated ItemData, plus helpers for equipping and thumbnails.
-- custom (hand made) items from CustomItems are looked up the same way as ItemData items, but all() only lists
-- the generated ItemData limiteds (what series and cases are built from).
-- api: ItemRegistry.all() -> the whole ItemData table (read only), ItemRegistry.custom() -> CustomItems table,
-- ItemRegistry.isCustom(assetId), ItemRegistry.isTool(assetId) (gear, only custom tools can be equipped), ItemRegistry.get(assetId), .baseValue(assetId), .tier(assetId), .accessoryType(assetId),
-- .isFace(assetId), .isEquippable(assetId), .kind(assetId) -> "Hat" | "Hair" | "Face" | "FaceDecal" | "Neck" | ... or nil,
-- .thumbnail(assetId, size?)

local ItemData = require(script.Parent.ItemData)
local CustomItems = require(script.Parent.CustomItems)
local Tiers = require(script.Parent.Tiers)

export type ItemInfo = {
	name: string,
	acronym: string,
	rap: number,
	value: number,
	valued: boolean,
	assetType: number,
	year: number,
	custom: boolean?,
}

local ACCESSORY_TYPES: { [number]: Enum.AccessoryType } = {
	[8] = Enum.AccessoryType.Hat,
	[41] = Enum.AccessoryType.Hair,
	[42] = Enum.AccessoryType.Face,
	[43] = Enum.AccessoryType.Neck,
	[44] = Enum.AccessoryType.Shoulder,
	[45] = Enum.AccessoryType.Front,
	[46] = Enum.AccessoryType.Back,
	[47] = Enum.AccessoryType.Waist,
}

local FACE_ASSET_TYPE = 18
local GEAR_ASSET_TYPE = 19

local KINDS: { [number]: string } = {
	[8] = "Hat",
	[41] = "Hair",
	[42] = "Face",
	[43] = "Neck",
	[44] = "Shoulder",
	[45] = "Front",
	[46] = "Back",
	[47] = "Waist",
	[FACE_ASSET_TYPE] = "FaceDecal",
	[GEAR_ASSET_TYPE] = "Tool",
}

local ITEMS: { [number]: ItemInfo } = table.clone(ItemData)
for assetId, info in CustomItems do
	assert(not ITEMS[assetId], `custom item {assetId} is already in ItemData`)
	ITEMS[assetId] = info
end

local ItemRegistry = {}

function ItemRegistry.all(): { [number]: ItemInfo }
	return ItemData
end

function ItemRegistry.custom(): { [number]: ItemInfo }
	return CustomItems
end

function ItemRegistry.isCustom(assetId: number): boolean
	return CustomItems[assetId] ~= nil
end

function ItemRegistry.get(assetId: number): ItemInfo?
	return ITEMS[assetId]
end

function ItemRegistry.baseValue(assetId: number): number
	local info = ITEMS[assetId]
	return info and info.value or 0
end

function ItemRegistry.tier(assetId: number): Tiers.Tier
	return Tiers.fromValue(ItemRegistry.baseValue(assetId))
end

function ItemRegistry.accessoryType(assetId: number): Enum.AccessoryType?
	local info = ITEMS[assetId]
	return info and ACCESSORY_TYPES[info.assetType]
end

function ItemRegistry.isFace(assetId: number): boolean
	local info = ITEMS[assetId]
	return info ~= nil and info.assetType == FACE_ASSET_TYPE
end

function ItemRegistry.isTool(assetId: number): boolean
	local info = ITEMS[assetId]
	return info ~= nil and info.assetType == GEAR_ASSET_TYPE
end

-- catalog gear stays unequippable (and out of series and cases), custom tools go in the backpack when equipped
function ItemRegistry.isEquippable(assetId: number): boolean
	return ItemRegistry.accessoryType(assetId) ~= nil
		or ItemRegistry.isFace(assetId)
		or (ItemRegistry.isTool(assetId) and ItemRegistry.isCustom(assetId))
end

function ItemRegistry.kind(assetId: number): string?
	local info = ITEMS[assetId]
	return info and KINDS[info.assetType]
end

function ItemRegistry.thumbnail(assetId: number, size: number?): string
	local s = size or 150
	return `rbxthumb://type=Asset&id={assetId}&w={s}&h={s}`
end

return ItemRegistry
