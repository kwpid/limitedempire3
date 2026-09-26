-- serial number bonuses. serials are handed out globally per item by the server SerialService.
-- api: Serial.multiplier(serial) -> number, Serial.label(serial) -> string? (short tag like "first print")

local Serial = {}

local PATTERNS = {
	[69] = true,
	[420] = true,
	[777] = true,
	[1337] = true,
	[6969] = true,
}

local function isRepdigit(n: number): boolean
	local s = tostring(n)
	return #s >= 3 and s == string.rep(s:sub(1, 1), #s)
end

local function isRound(n: number): boolean
	return n >= 1000 and n % 1000 == 0
end

function Serial.multiplier(serial: number): number
	if serial == 1 then
		return 3
	elseif serial <= 10 then
		return 1.75
	elseif serial <= 100 then
		return 1.25
	elseif PATTERNS[serial] or isRepdigit(serial) or isRound(serial) then
		return 1.15
	end
	return 1
end

function Serial.label(serial: number): string?
	if serial == 1 then
		return "First Print"
	elseif serial <= 10 then
		return "Top 10"
	elseif serial <= 100 then
		return "Top 100"
	elseif PATTERNS[serial] or isRepdigit(serial) or isRound(serial) then
		return "Special"
	end
	return nil
end

return Serial
