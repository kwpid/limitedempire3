-- hand made items that are not in the generated ItemData (not Rolimons limiteds), like event exclusives.
-- same fields as ItemData plus custom = true, and optionally rarity = a custom rarity id from Tiers.custom
-- ("alpha", "dev") instead of the rarity its value would give. they are never put in series or cases on their
-- own, they are given out another way (events later, the admin data editor for now).
--
-- the server needs the item's real Accessory or Tool (the catalog based avatar loading can't use custom uploads):
--   1. best: in Studio, insert the asset and put its Accessory or Tool in ServerStorage > CustomItemModels (create
--      the folder), renamed to the asset id, e.g. "88804150792706". always works, also gives the 3d preview.
--   2. otherwise the server tries InsertService:LoadAsset, which Roblox only allows when the game's owner owns the
--      asset (the same account, or the group for group games). the output says when this fails.
-- assetType: 8 hat, 41 hair, 42 face accessory, 43 neck, 44 shoulder, 45 front, 46 back, 47 waist, 18 face,
-- 19 tool (goes in the backpack when equipped)

return {
	[97688070021673] = {
		name = "Immortal Sword: Chroma Intent",
		rarity = "dev",
		acronym = "",
		rap = 250000,
		value = 250000,
		valued = true,
		assetType = 8,
		year = 2026,
		custom = true,
	},
	[79714900624693] = {
		name = "2026 Bloxy Award (Alpha Reward)",
		rarity = "alpha",
		acronym = "",
		rap = 0,
		value = 0,
		valued = true,
		assetType = 19,
		year = 2026,
		custom = true,
	},
}
