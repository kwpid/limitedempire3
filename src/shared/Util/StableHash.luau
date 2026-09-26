-- small deterministic hashes (fnv style) for splitting items into groups the same way on every server and client.
-- api: StableHash.number(n, salt) -> 32 bit integer, StableHash.string(s, salt?) -> 32 bit integer

local StableHash = {}

function StableHash.string(text: string, salt: number?): number
	local h = bit32.bxor(2166136261, salt or 0)
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return h
end

function StableHash.number(n: number, salt: number): number
	return StableHash.string(tostring(n), salt)
end

return StableHash
