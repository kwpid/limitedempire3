-- higher or lower rules. the server shows an item with its value and a second item without; the player guesses if
-- the second is worth more or less. each correct guess in a row pays REWARD_PER_STREAK times the streak (capped at
-- MAX_STREAK_PAY), up to DAILY_CAP per player per day (utc). a wrong guess ends the run. values are base values.
-- the second item is picked within MAX_RATIO of the first so rounds aren't obvious.

local HigherLower = {}

HigherLower.REWARD_PER_STREAK = 150
HigherLower.MAX_STREAK_PAY = 12
HigherLower.DAILY_CAP = 30_000
HigherLower.MAX_RATIO = 4

function HigherLower.reward(streak: number): number
	return HigherLower.REWARD_PER_STREAK * math.min(streak, HigherLower.MAX_STREAK_PAY)
end

function HigherLower.today(): number
	return math.floor(os.time() / 86400)
end

return HigherLower
