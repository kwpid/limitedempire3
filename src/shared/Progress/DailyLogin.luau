-- the daily login calendar: claim once per day (utc, same days as Seasons.today) to keep a streak going. the streak
-- walks through DAYS rewards and starts over after the last one; missing a day resets it to day 1.
-- each claim also gives Career.XP.dailyLogin and counts as a login for quests. cash rewards get the cash boost and
-- Season Points get the event multiplier and the sp boost.
-- api: DailyLogin.DAYS, DailyLogin.REWARDS[day] -> { cash, sp, big? }, DailyLogin.dayFor(streak) -> 1..DAYS,
-- DailyLogin.view(login, today) -> { streak, day, claimable, claimedToday }

local DailyLogin = {}

DailyLogin.REWARDS = {
	{ cash = 2_500, sp = 25 },
	{ cash = 5_000, sp = 30 },
	{ cash = 7_500, sp = 35 },
	{ cash = 10_000, sp = 40 },
	{ cash = 12_500, sp = 50 },
	{ cash = 15_000, sp = 60 },
	{ cash = 35_000, sp = 120, big = true },
	{ cash = 17_500, sp = 65 },
	{ cash = 20_000, sp = 70 },
	{ cash = 22_500, sp = 80 },
	{ cash = 25_000, sp = 90 },
	{ cash = 30_000, sp = 100 },
	{ cash = 35_000, sp = 110 },
	{ cash = 100_000, sp = 300, big = true },
}
DailyLogin.DAYS = #DailyLogin.REWARDS

function DailyLogin.dayFor(streak: number): number
	return ((math.max(streak, 1) - 1) % DailyLogin.DAYS) + 1
end

-- login = { streak, lastClaimDay } from the player's data. day is the calendar day claimed today, or the one the
-- next claim gives
function DailyLogin.view(login, today: number)
	local lastClaimDay = login and login.lastClaimDay or 0
	local claimedToday = lastClaimDay == today
	local alive = lastClaimDay >= today - 1
	local streak = if alive and login then login.streak or 0 else 0
	return {
		streak = streak,
		claimedToday = claimedToday,
		claimable = not claimedToday,
		day = if claimedToday then DailyLogin.dayFor(streak) else DailyLogin.dayFor(streak + 1),
	}
end

return DailyLogin
