-- hand made items that are not in the generated ItemData (not Rolimons limiteds), like event exclusives.
-- same fields as ItemData plus custom = true. they are never put in series or cases on their own, they are given
-- out another way (events later, the admin data editor for now).
-- the asset must be an accessory the game owner owns (InsertService loads it for previews and to wear it, the
-- catalog based avatar loading can't use off sale uploads).
-- assetType: 8 hat, 41 hair, 42 face accessory, 43 neck, 44 shoulder, 45 front, 46 back, 47 waist, 18 face

return {
	-- test item: a recolor of an existing roblox item. assetType is a guess (hat), change it if it is another kind
	[97688070021673] = {
		name = "Immortal Sword: Chroma Intent",
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
		acronym = "",
		rap = 0,
		value = 0,
		valued = true,
		assetType = 8,
		year = 2026,
		custom = true,
	},
}
