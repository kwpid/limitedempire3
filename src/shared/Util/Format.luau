-- number and text formatting helpers for display.
-- api: Format.short(n) -> "1.25M", Format.commas(n) -> "1,250,000", Format.cash(n) -> "T$1.25M",
-- Format.percent(0.0123) -> "1.23%", Format.float(f) -> "0.021337", Format.serial(n) -> "#7"

local Config = require(script.Parent.Parent.Config)

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

function Format.short(n: number): string
	local negative = n < 0
	n = math.abs(n)
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(n))
	elseif n >= 100 then
		text = string.format("%.0f", math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

function Format.commas(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (n < 0 and "-" or "") .. formatted
end

function Format.cash(n: number): string
	return Config.Currency.Symbol .. Format.short(n)
end

function Format.percent(chance: number): string
	local pct = chance * 100
	if pct >= 10 then
		return string.format("%.1f%%", pct)
	elseif pct >= 1 then
		return string.format("%.2f%%", pct)
	elseif pct >= 0.01 then
		return string.format("%.3f%%", pct)
	end
	return string.format("%.5f%%", pct)
end

function Format.float(f: number): string
	return string.format("%.6f", f)
end

-- "1 in 1,234" for a chance between 0 and 1
function Format.odds(chance: number): string
	if chance <= 0 then
		return "-"
	end
	return "1 in " .. Format.commas(math.max(1, math.floor(1 / chance + 0.5)))
end

function Format.serial(n: number): string
	return "#" .. Format.commas(n)
end

return Format
