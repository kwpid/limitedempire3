-- turns SeriesData into membership lists over every wearable item in ItemData. shared so the server and ui agree on
-- which series an item is in.
--
-- a "series" here is one playable unit: a series without volumes, one volume of a split series ("royalty2" is
-- Royalty II) or an era series. the theme it came from is its group ("royalty").
-- api: SeriesRegistry.get(seriesId) -> Series?, SeriesRegistry.name(seriesId?) -> string,
-- SeriesRegistry.of(assetId) -> { seriesId } (every series the item is in, most specific first),
-- SeriesRegistry.group(groupId) -> { assetId } (all volumes of a theme together, used for case guests)

local Shared = script.Parent.Parent
local ItemRegistry = require(Shared.Items.ItemRegistry)
local StableHash = require(Shared.Util.StableHash)
local SeriesData = require(script.Parent.SeriesData)

export type Series = {
	id: string,
	group: string,
	name: string,
	items: { number },
}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

type Rule = { phrase: { string }, prefix: { boolean } }

local function wordsOf(name: string): { string }
	local words = {}
	for word in string.gmatch(string.lower(string.gsub(name, "'", "")), "%w+") do
		table.insert(words, word)
	end
	return words
end

local function compile(keyword: string): Rule
	local rule: Rule = { phrase = {}, prefix = {} }
	for part in string.gmatch(string.lower(keyword), "%S+") do
		local isPrefix = string.sub(part, -1) == "*"
		table.insert(rule.phrase, if isPrefix then string.sub(part, 1, -2) else part)
		table.insert(rule.prefix, isPrefix)
	end
	return rule
end

local function matches(words: { string }, rule: Rule): boolean
	local length = #rule.phrase
	for start = 1, #words - length + 1 do
		local ok = true
		for offset = 1, length do
			local word = words[start + offset - 1]
			local part = rule.phrase[offset]
			if rule.prefix[offset] then
				if string.sub(word, 1, #part) ~= part then
					ok = false
					break
				end
			elseif word ~= part then
				ok = false
				break
			end
		end
		if ok then
			return true
		end
	end
	return false
end

local byId: { [string]: Series } = {}
local byGroup: { [string]: { number } } = {}
local ofItem: { [number]: { string } } = {}

local compiled = {}
for _, def in SeriesData.series do
	assert(not byGroup[def.id], `duplicate series id "{def.id}"`)
	byGroup[def.id] = {}
	local kinds = {}
	for _, kind in def.kinds or {} do
		kinds[kind] = true
	end
	local rules = {}
	for _, keyword in def.keywords do
		table.insert(rules, compile(keyword))
	end
	local volumes = def.volumes or 1
	for volume = 1, volumes do
		local id = if volumes > 1 then def.id .. volume else def.id
		byId[id] = {
			id = id,
			group = def.id,
			name = if volumes > 1 then `{def.name} {ROMAN[volume] or volume}` else def.name,
			items = {},
		}
	end
	table.insert(compiled, { def = def, kinds = kinds, rules = rules, volumes = volumes })
end
for _, era in SeriesData.eras do
	assert(not byGroup[era.id], `duplicate series id "{era.id}"`)
	byGroup[era.id] = {}
	byId[era.id] = { id = era.id, group = era.id, name = era.name, items = {} }
end

local function join(assetId: number, series: Series)
	table.insert(series.items, assetId)
	table.insert(byGroup[series.group], assetId)
	table.insert(ofItem[assetId], series.id)
end

local assetIds = {}
for assetId in ItemRegistry.all() do
	if ItemRegistry.isEquippable(assetId) and ItemRegistry.baseValue(assetId) > 0 then
		table.insert(assetIds, assetId)
	end
end
table.sort(assetIds)

for _, assetId in assetIds do
	ofItem[assetId] = {}
	local info = ItemRegistry.get(assetId)
	local kind = ItemRegistry.kind(assetId)
	local words = wordsOf(info and info.name or "")
	for _, entry in compiled do
		if #ofItem[assetId] >= SeriesData.maxPerItem then
			break
		end
		local hit = kind ~= nil and entry.kinds[kind] == true
		if not hit then
			for _, rule in entry.rules do
				if matches(words, rule) then
					hit = true
					break
				end
			end
		end
		if hit then
			local id = entry.def.id
			if entry.volumes > 1 then
				id ..= StableHash.number(assetId, SeriesData.volumeSalt) % entry.volumes + 1
			end
			join(assetId, byId[id])
		end
	end
	if #ofItem[assetId] == 0 then
		local year = info and info.year or 0
		for _, era in SeriesData.eras do
			if year >= era.fromYear and year <= era.toYear then
				join(assetId, byId[era.id])
				break
			end
		end
	end
end

local SeriesRegistry = {}

function SeriesRegistry.get(seriesId: string): Series?
	return byId[seriesId]
end

function SeriesRegistry.name(seriesId: string?): string
	local series = seriesId and byId[seriesId]
	return if series then series.name else "Unknown"
end

function SeriesRegistry.of(assetId: number): { string }
	return ofItem[assetId] or {}
end

function SeriesRegistry.group(groupId: string): { number }
	return byGroup[groupId] or {}
end

return SeriesRegistry
