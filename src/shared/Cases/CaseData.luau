-- case setup. every wearable limited in ItemData is split across the cases below, so each case is a full ladder
-- from cheap commons up to its own hidden "rare special items" (every item in the specialTier and above).
-- items are assigned by a stable hash of their asset id (salt), so regenerating ItemData never moves items
-- between cases. salt 329 gives the most even split (402 to 420 items and 16 to 19 specials per case).
--
-- fields: salt, curve (odds are value^-curve inside each group, lower = pricier items drop more),
-- specialChance (combined odds of hitting the hidden special pool, 0.0015 = 1 in 667),
-- specialTier (tier id from Tiers, that tier and above are hidden), cases (id, name, order, color).
-- add a case by adding an entry, every case then gets roughly items / #cases.

return {
	salt = 329,
	curve = 0.9,
	specialChance = 0.0015,
	specialTier = "mythic",
	cases = {
		{ id = "genesis", name = "Genesis Case", order = 1, color = Color3.fromRGB(120, 200, 140) },
		{ id = "vanguard", name = "Vanguard Case", order = 2, color = Color3.fromRGB(90, 150, 255) },
		{ id = "eclipse", name = "Eclipse Case", order = 3, color = Color3.fromRGB(176, 102, 255) },
		{ id = "ember", name = "Ember Case", order = 4, color = Color3.fromRGB(255, 140, 70) },
		{ id = "frost", name = "Frost Case", order = 5, color = Color3.fromRGB(150, 230, 255) },
	},
}
