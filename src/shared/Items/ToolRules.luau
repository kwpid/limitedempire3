-- decides which tools keep their scripts. fighting tools have their scripts removed when they are loaded, so they
-- can be held but never deal damage. travel and harmless tools (skateboards, hoverboards, gliders, balloons...)
-- keep them and work like normal.
--
-- catalog gear counts as fighting unless it is in SAFE or its name has one of SAFE_WORDS: weapons have too many
-- different names to catch them all, so anything unknown is treated as a weapon. custom items keep their scripts
-- unless they set combat = true in CustomItems. to fix a tool that is sorted wrong, add its asset id to SAFE (keep
-- scripts) or COMBAT (remove scripts), those win over everything else.
-- api: ToolRules.isCombat(assetId) -> boolean

local ItemRegistry = require(script.Parent.ItemRegistry)

-- always fighting tools, by asset id
local COMBAT: { [number]: boolean } = {}

-- always safe tools, by asset id
local SAFE: { [number]: boolean } = {}

-- words (or word starts, with *) in the name that mark travel or harmless gear, multi word entries must appear in order
local SAFE_WORDS = {
	"skateboard*", "hoverboard*", "glider*", "airwalker*", "balloon*", "blimp*", "stunter*", "rail runner*",
	"ilift", "surfboard*", "jetpack*", "coil*", "carpet*", "plushie*", "sign", "tablet*", "badge", "lantern*",
	"snowglobe*", "chalice*", "chair*",
}

local ToolRules = {}

local function words(name: string): { string }
	local list = {}
	for word in string.gmatch(string.lower(string.gsub(name, "'", "")), "%w+") do
		table.insert(list, word)
	end
	return list
end

local function wordMatches(word: string, part: string): boolean
	if string.sub(part, -1) == "*" then
		local prefix = string.sub(part, 1, -2)
		return string.sub(word, 1, #prefix) == prefix
	end
	return word == part
end

local function hasPhrase(nameWords: { string }, phrase: string): boolean
	local parts = string.split(phrase, " ")
	for start = 1, #nameWords - #parts + 1 do
		local ok = true
		for offset, part in parts do
			if not wordMatches(nameWords[start + offset - 1], part) then
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

function ToolRules.isCombat(assetId: number): boolean
	if COMBAT[assetId] then
		return true
	elseif SAFE[assetId] then
		return false
	end
	local info = ItemRegistry.get(assetId) :: any
	if not info then
		return true
	end
	if info.custom then
		return info.combat == true
	end
	local nameWords = words(info.name)
	for _, phrase in SAFE_WORDS do
		if hasPhrase(nameWords, phrase) then
			return false
		end
	end
	return true
end

return ToolRules
