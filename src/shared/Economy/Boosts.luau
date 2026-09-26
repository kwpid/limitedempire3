-- timed multipliers (from codes, see CodeService): cash, xp and sp. the server keeps them in the player's data
-- (BoostService) and mirrors each active one to player attributes so the client can show a timer.
--   cash: earned cash (passive income, quest rewards, daily login, Higher or Lower). never selling or bets, or a
--         boost would turn buying cases or betting into free money
--   xp:   career xp,  sp: Season Points
-- a second boost of the same kind adds its time and keeps the higher multiplier.
-- api: Boosts.ORDER, Boosts.KINDS[kind] -> { name, color }, Boosts.attribute(kind), Boosts.endsAttribute(kind)

local Boosts = {}

Boosts.ORDER = { "cash", "xp", "sp" }

Boosts.KINDS = {
	cash = { name = "Cash", color = Color3.fromRGB(229, 186, 71) },
	xp = { name = "XP", color = Color3.fromRGB(120, 190, 255) },
	sp = { name = "SP", color = Color3.fromRGB(180, 110, 255) },
}

function Boosts.attribute(kind: string): string
	return `Boost_{kind}`
end

function Boosts.endsAttribute(kind: string): string
	return `Boost_{kind}_ends`
end

return Boosts
