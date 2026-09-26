-- season schedule and Season Point rules. edit the values at the top to run seasons:
--   SEASON0_END: when the alpha season (Season 0) ends, as a unix time (os.time()) or nil while it keeps running.
--     e.g. os.time({ year = 2026, month = 12, day = 1, hour = 0 }) (server time is UTC).
--   LENGTH_DAYS: how long every regular season lasts once Season 0 is over. Season 1 starts when Season 0 ends,
--     Season 2 LENGTH_DAYS later, and so on.
--   SP_MULTIPLIER: event multiplier on every Season Point earned (admins can also change it live from the panel).
--   CASES: the season case id for each season (see CaseData, a case with season = n).
--   LEADERBOARD_MIN_SP: the Season Points top 100 only lists players with at least this much (Legend). admins can
--     switch it to all ranks from the panel (per server, for testing); LEADERBOARD_ALL_RANKS is the default.
--   RANK_REWARDS / TOP_REWARDS: end of season rewards (see below).
-- api: Seasons.current(now?) -> (id, startsAt, endsAt?), Seasons.range(id) -> (startsAt, endsAt?),
-- Seasons.name(id), Seasons.caseFor(id) -> caseId?, Seasons.topReward(placement) -> TopReward?,
-- Seasons.softReset(sp) -> sp, Seasons.decay(sp, inactiveDays) -> sp, Seasons.today() -> day number (utc)

local Seasons = {}

Seasons.SEASON0_END = nil :: number?
Seasons.LENGTH_DAYS = 30
Seasons.SP_MULTIPLIER = 1

Seasons.NAMES = {
	[0] = "Season 0 · Alpha",
}

Seasons.CASES = {
	[0] = "alpha",
}

-- start of a new season: keep SOFT_RESET_KEEP of your SP, at most SOFT_RESET_CAP
Seasons.SOFT_RESET_KEEP = 0.3
Seasons.SOFT_RESET_CAP = 3_500

-- inactivity: after GRACE_DAYS days without earning SP, lose DECAY_RATE of your SP for every extra day
Seasons.GRACE_DAYS = 2
Seasons.DECAY_RATE = 0.08

Seasons.DAILY_LOGIN_SP = 25

Seasons.LEADERBOARD_MIN_SP = 50_000
Seasons.LEADERBOARD_ALL_RANKS = false

-- end of season rewards, paid the first time a player joins after the season ended (only if they earned SP in it).
-- everyone gets their final rank's title ("S0 Gold", Shared/Titles makes one per season and rank) and cash.
-- Legends in the top 100 also get the best placement title they reached and its cash on top.
Seasons.RANK_REWARDS = {
	bronze = 10_000,
	silver = 35_000,
	gold = 100_000,
	diamond = 300_000,
	champion = 1_000_000,
	legend = 3_000_000,
}

export type TopReward = { id: string, name: string, place: number, cash: number }

-- best first. place = the lowest placement that still gets it
Seasons.TOP_REWARDS = {
	{ id = "top1", name = "Top Champion", place = 1, cash = 50_000_000 },
	{ id = "top5", name = "Top 5 Legend", place = 5, cash = 25_000_000 },
	{ id = "top10", name = "Top 10 Legend", place = 10, cash = 15_000_000 },
	{ id = "top25", name = "Top 25 Legend", place = 25, cash = 7_500_000 },
	{ id = "top50", name = "Top 50 Legend", place = 50, cash = 4_000_000 },
	{ id = "top100", name = "Top 100 Legend", place = 100, cash = 2_000_000 },
} :: { TopReward }

local DAY = 86400

function Seasons.today(now: number?): number
	return math.floor((now or os.time()) / DAY)
end

function Seasons.current(now: number?): (number, number, number?)
	local t = now or os.time()
	local endOfZero = Seasons.SEASON0_END
	if not endOfZero or t < endOfZero then
		return 0, 0, endOfZero
	end
	local length = Seasons.LENGTH_DAYS * DAY
	local index = math.floor((t - endOfZero) / length)
	local startsAt = endOfZero + index * length
	return index + 1, startsAt, startsAt + length
end

function Seasons.range(id: number): (number, number?)
	local endOfZero = Seasons.SEASON0_END
	if id == 0 then
		return 0, endOfZero
	end
	assert(endOfZero, "only Season 0 exists until SEASON0_END is set")
	local length = Seasons.LENGTH_DAYS * DAY
	local startsAt = endOfZero + (id - 1) * length
	return startsAt, startsAt + length
end

function Seasons.topReward(placement: number): TopReward?
	for _, reward in Seasons.TOP_REWARDS do
		if placement <= reward.place then
			return reward
		end
	end
	return nil
end

function Seasons.name(id: number): string
	return Seasons.NAMES[id] or `Season {id}`
end

function Seasons.caseFor(id: number): string?
	return Seasons.CASES[id]
end

function Seasons.softReset(sp: number): number
	return math.min(math.floor(sp * Seasons.SOFT_RESET_KEEP), Seasons.SOFT_RESET_CAP)
end

function Seasons.decay(sp: number, inactiveDays: number): number
	local days = inactiveDays - Seasons.GRACE_DAYS
	if days <= 0 then
		return sp
	end
	return math.floor(sp * (1 - Seasons.DECAY_RATE) ^ days)
end

return Seasons
