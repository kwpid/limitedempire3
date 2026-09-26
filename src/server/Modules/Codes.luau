-- redeemable codes. to add one, copy a line and change it. codes are case-insensitive and each player can redeem
-- each code once. this list stays on the server, so players can't read it.
--
-- fields:
--   code     the text players type
--   rewards  a list of any of:
--              { cash = 50_000 }                                  adds currency
--              { boost = "cash", multiplier = 2, minutes = 30 }   cash multiplier for 30 minutes
--              { boost = "xp", multiplier = 2, minutes = 60 }     xp multiplier
--              { boost = "sp", multiplier = 1.5, minutes = 30 }   Season Points multiplier
--   expires  optional "YYYY-MM-DD": the last day (UTC) the code works
--   active   optional, false turns a code off without deleting it

return {
	{ code = "RELEASE", rewards = { { cash = 50_000 } } },
	{ code = "DOUBLEUP", rewards = { { boost = "cash", multiplier = 2, minutes = 30 } } },
	{ code = "XPRUSH", rewards = { { boost = "xp", multiplier = 2, minutes = 60 } } },
	{ code = "SPRINT", rewards = { { boost = "sp", multiplier = 1.5, minutes = 30 } } },
	{
		code = "LIMITED",
		rewards = { { cash = 25_000 }, { boost = "cash", multiplier = 1.5, minutes = 15 } },
		expires = "2026-12-31",
	},
}
