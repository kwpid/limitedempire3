-- passive income: every player online earns cash each minute, more as their career level goes up.
-- per minute = BASE_PER_MINUTE + PER_LEVEL for each level past 1, up to MAX_PER_MINUTE.
-- for scale: cases cost about 4.6k to 22k (median ~11k), so level 1 covers a cheap case every ~5 minutes, and the
-- cap is reached at level 268.
-- api: Income.perMinute(level) -> number, Income.INTERVAL (seconds between payouts)

local Income = {}

Income.BASE_PER_MINUTE = 1_000
Income.PER_LEVEL = 15
Income.MAX_PER_MINUTE = 5_000
Income.INTERVAL = 60

function Income.perMinute(level: number): number
	return math.min(Income.BASE_PER_MINUTE + Income.PER_LEVEL * math.max(level - 1, 0), Income.MAX_PER_MINUTE)
end

return Income
