-- season schedule and Season Point rules. edit the values at the top to run seasons:
--   SEASON0_END: when the alpha season (Season 0) ends, as a unix time (os.time()) or nil while it keeps running.
--     e.g. os.time({ year = 2026, month = 12, day = 1, hour = 0 }) (server time is UTC).
--   LENGTH_DAYS: how long every regular season lasts once Season 0 is over. Season 1 starts when Season 0 ends,
--     Season 2 LENGTH_DAYS later, and so on.
--   SP_MULTIPLIER: event multiplier on every Season Point earned (admins can also change it live from the panel).
--   CASES: the season case id for each season (see CaseData, a case with season = n).
-- api: Seasons.current(now?) -> (id, startsAt, endsAt?), Seasons.name(id), Seasons.caseFor(id) -> caseId?,
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
