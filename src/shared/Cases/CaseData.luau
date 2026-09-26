-- case setup. every wearable limited in ItemData is split across the cases below, so each case is a full ladder
-- from cheap commons up to its own hidden "rare special items" (every item in the specialTier and above).
-- items are assigned by a stable hash of their asset id (salt), so regenerating ItemData never moves items
-- between cases. salt 3701 gives the most even split across 12 cases (161 to 184 items and 5 to 10 specials per case).
--
-- fields: salt, curve (odds are value^-curve inside each group, lower = pricier items drop more),
-- specialChance (combined odds of hitting the hidden special pool, 0.0015 = 1 in 667),
-- specialTier (tier id from Tiers, that tier and above are hidden), cases (id, name, order, color).
-- add a case by adding an entry, every case then gets roughly items / #cases.

return {
	salt = 3701,
	curve = 0.9,
	specialChance = 0.0015,
	specialTier = "mythic",
	cases = {
		{ id = "genesis", name = "Genesis Case", order = 1, color = Color3.fromRGB(120, 200, 140) },
		{ id = "vanguard", name = "Vanguard Case", order = 2, color = Color3.fromRGB(90, 150, 255) },
		{ id = "eclipse", name = "Eclipse Case", order = 3, color = Color3.fromRGB(176, 102, 255) },
		{ id = "ember", name = "Ember Case", order = 4, color = Color3.fromRGB(255, 140, 70) },
		{ id = "frost", name = "Frost Case", order = 5, color = Color3.fromRGB(150, 230, 255) },
		{ id = "verdant", name = "Verdant Case", order = 6, color = Color3.fromRGB(110, 190, 70) },
		{ id = "tempest", name = "Tempest Case", order = 7, color = Color3.fromRGB(120, 140, 200) },
		{ id = "solar", name = "Solar Case", order = 8, color = Color3.fromRGB(255, 205, 70) },
		{ id = "abyss", name = "Abyss Case", order = 9, color = Color3.fromRGB(60, 90, 170) },
		{ id = "crimson", name = "Crimson Case", order = 10, color = Color3.fromRGB(220, 60, 70) },
		{ id = "phantom", name = "Phantom Case", order = 11, color = Color3.fromRGB(200, 200, 220) },
		{ id = "nova", name = "Nova Case", order = 12, color = Color3.fromRGB(255, 110, 200) },
	},
}
