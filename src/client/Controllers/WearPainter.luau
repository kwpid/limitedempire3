local WearPainter = {}

local SCRATCH_SEGMENTS = 24
local BUDGET = 0.003

local GRIME = { 58, 48, 40 }
local HAZE = { 226, 221, 210 }
local RUST = { 124, 72, 36 }
local DIRT = { 30, 24, 19 }
local SMUDGE = { 72, 64, 56 }
local DUST = { 186, 178, 166 }
local CHIP = { 198, 192, 180 }
local CHIP_RIM = { 38, 32, 26 }
local SCRATCH = { 208, 202, 192 }

local LAYER_FILM = 1
local LAYER_HAZE = 2
local LAYER_RUST = 3
local LAYER_BLOTCH = 4
local LAYER_SMUDGE = 5
local LAYER_DUST = 6
local LAYER_CHIP = 7
local LAYER_SCRATCH = 8
local LAYER_MICRO = 9

local yielder: (() -> ())? = nil
local deadline = 0

local function checkpoint()
	if yielder and os.clock() > deadline then
		yielder()
		deadline = os.clock() + BUDGET
	end
end

@native
local function seedFrom(uid: string): number
	local hash = 5381
	for i = 1, #uid do
		hash = (hash * 33 + string.byte(uid, i)) % 2147483647
	end
	return hash
end

@native
local function layerRng(seed: number, layer: number, index: number): Random
	return Random.new((seed + layer * 1000003 + index * 7919) % 2147483647)
end

@native
local function blend(buf: buffer, size: number, x: number, y: number, r: number, g: number, b: number, alpha: number)
	if alpha <= 0.004 or x < 0 or y < 0 or x >= size or y >= size then
		return
	end
	local i = (y * size + x) * 4
	local dstAlpha = buffer.readu8(buf, i + 3) / 255
	local outAlpha = alpha + dstAlpha * (1 - alpha)
	local keep = dstAlpha * (1 - alpha)
	buffer.writeu8(buf, i, math.floor((r * alpha + buffer.readu8(buf, i) * keep) / outAlpha))
	buffer.writeu8(buf, i + 1, math.floor((g * alpha + buffer.readu8(buf, i + 1) * keep) / outAlpha))
	buffer.writeu8(buf, i + 2, math.floor((b * alpha + buffer.readu8(buf, i + 2) * keep) / outAlpha))
	buffer.writeu8(buf, i + 3, math.floor(math.min(outAlpha, 1) * 255))
end

@native
local function blendColor(buf: buffer, size: number, x: number, y: number, color: { number }, alpha: number)
	blend(buf, size, x, y, color[1], color[2], color[3], alpha)
end

@native
local function ellipse(buf: buffer, size: number, cx: number, cy: number, rx: number, ry: number, rotation: number, color: { number }, strength: number, hardness: number)
	local c, s = math.cos(rotation), math.sin(rotation)
	local halfW = math.sqrt((rx * c) ^ 2 + (ry * s) ^ 2)
	local halfH = math.sqrt((rx * s) ^ 2 + (ry * c) ^ 2)
	local step = if size >= 512 then 2 else 1
	local r, g, b = color[1], color[2], color[3]
	local x0 = math.max(0, math.floor((cx - halfW) / step) * step)
	local x1 = math.min(size - 1, math.ceil(cx + halfW))
	local y0 = math.max(0, math.floor((cy - halfH) / step) * step)
	local y1 = math.min(size - 1, math.ceil(cy + halfH))
	for py = y0, y1, step do
		for px = x0, x1, step do
			local dx, dy = px - cx, py - cy
			local u = (dx * c + dy * s) / rx
			local v = (-dx * s + dy * c) / ry
			local d = u * u + v * v
			if d < 1 then
				local alpha = strength * (1 - d) ^ hardness
				for oy = 0, step - 1 do
					for ox = 0, step - 1 do
						blend(buf, size, px + ox, py + oy, r, g, b, alpha)
					end
				end
			end
		end
		checkpoint()
	end
end

@native
local function paintBase(buf: buffer, size: number, seed: number, wear: number)
	local filmRng = layerRng(seed, LAYER_FILM, 0)
	local filmStrength = 0.05 + wear * 0.45
	local fx, fy = filmRng:NextNumber(0, 500), filmRng:NextNumber(0, 500)
	local filmFreq = 6 / size

	local hazeRng = layerRng(seed, LAYER_HAZE, 0)
	local hazeStrength = if wear >= 0.3 then (wear - 0.3) * 0.4 else 0
	local hx, hy = hazeRng:NextNumber(0, 500), hazeRng:NextNumber(0, 500)
	local hazeFreq = 3 / size

	for y = 0, size - 1, 2 do
		for x = 0, size - 1, 2 do
			local n = math.noise(x * filmFreq + fx, y * filmFreq + fy) + 0.5 * math.noise(x * filmFreq * 3 + fy, y * filmFreq * 3 + fx)
			local filmAlpha = filmStrength * math.clamp(0.5 + n, 0, 1)
			local r, g, b, a = GRIME[1], GRIME[2], GRIME[3], filmAlpha
			if hazeStrength > 0 then
				local hazeAlpha = hazeStrength * math.clamp(0.5 + math.noise(x * hazeFreq + hx, y * hazeFreq + hy) * 1.4, 0, 1)
				local outAlpha = hazeAlpha + a * (1 - hazeAlpha)
				if outAlpha > 0 then
					local keep = a * (1 - hazeAlpha)
					r = (HAZE[1] * hazeAlpha + r * keep) / outAlpha
					g = (HAZE[2] * hazeAlpha + g * keep) / outAlpha
					b = (HAZE[3] * hazeAlpha + b * keep) / outAlpha
				end
				a = outAlpha
			end
			local alpha = math.floor(math.min(a, 1) * 255)
			r, g, b = math.floor(r), math.floor(g), math.floor(b)
			for dy = 0, 1 do
				local row = (y + dy) * size
				for dx = 0, 1 do
					local i = (row + x + dx) * 4
					buffer.writeu8(buf, i, r)
					buffer.writeu8(buf, i + 1, g)
					buffer.writeu8(buf, i + 2, b)
					buffer.writeu8(buf, i + 3, alpha)
				end
			end
		end
		checkpoint()
	end
end

@native
local function paintRust(buf: buffer, size: number, seed: number, wear: number)
	if wear < 0.45 then
		return
	end
	local count = math.floor((wear - 0.45) * 22)
	for index = 1, count do
		local rng = layerRng(seed, LAYER_RUST, index)
		local cx, cy = rng:NextNumber() * size, rng:NextNumber() * size
		local r = size * rng:NextNumber(0.03, 0.1)
		ellipse(buf, size, cx, cy, r, r * rng:NextNumber(0.6, 1), rng:NextNumber(0, math.pi), RUST, rng:NextNumber(0.12, 0.3) * wear, 1.4)
	end
end

@native
local function paintBlotches(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear ^ 1.2 * 28)
	for index = 1, count do
		local rng = layerRng(seed, LAYER_BLOTCH, index)
		local cx, cy = rng:NextNumber() * size, rng:NextNumber() * size
		local r = size * rng:NextNumber(0.01, 0.03 + 0.06 * wear)
		ellipse(buf, size, cx, cy, r, r, 0, DIRT, rng:NextNumber(0.2, 0.35 + 0.4 * wear), 2)
	end
end

@native
local function paintSmudges(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear ^ 1.1 * 16)
	for index = 1, count do
		local rng = layerRng(seed, LAYER_SMUDGE, index)
		local cx, cy = rng:NextNumber() * size, rng:NextNumber() * size
		local rx = size * rng:NextNumber(0.03, 0.06 + 0.07 * wear)
		local ry = rx * rng:NextNumber(0.15, 0.35)
		local rotation = rng:NextNumber(0, math.pi)
		local strength = rng:NextNumber(0.1, 0.2 + 0.18 * wear)
		local stepX, stepY = math.cos(rotation) * rx * 0.45, math.sin(rotation) * rx * 0.45
		for streak = 0, 1 do
			ellipse(buf, size, cx + stepX * streak, cy + stepY * streak, rx * (1 - streak * 0.25), ry, rotation, SMUDGE, strength * (1 - streak * 0.35), 1.2)
		end
	end
end

@native
local function paintDust(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear * 700)
	local rng = layerRng(seed, LAYER_DUST, 0)
	local r, g, b = DUST[1], DUST[2], DUST[3]
	for index = 1, count do
		local x, y = math.floor(rng:NextNumber() * size), math.floor(rng:NextNumber() * size)
		local alpha = rng:NextNumber(0.15, 0.45)
		blend(buf, size, x, y, r, g, b, alpha)
		if size >= 512 then
			blend(buf, size, x + 1, y, r, g, b, alpha * 0.7)
			blend(buf, size, x, y + 1, r, g, b, alpha * 0.7)
		end
		if index % 200 == 0 then
			checkpoint()
		end
	end
end

@native
local function paintChips(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear ^ 1.6 * 40)
	local rim = math.max(1, size / 256)
	for index = 1, count do
		local rng = layerRng(seed, LAYER_CHIP, index)
		local cx, cy = rng:NextNumber() * size, rng:NextNumber() * size
		local radius = size * rng:NextNumber(0.004, 0.012 + 0.012 * wear)
		local jag = rng:NextNumber(0, 100)
		local extent = math.ceil(radius + rim + 1)
		for py = math.floor(cy) - extent, math.floor(cy) + extent do
			for px = math.floor(cx) - extent, math.floor(cx) + extent do
				local dx, dy = px - cx, py - cy
				local dist = math.sqrt(dx * dx + dy * dy)
				local edge = radius * (0.65 + 0.35 * (math.noise(math.atan2(dy, dx) * 1.5 + jag, jag) + 0.5))
				if dist < edge then
					blendColor(buf, size, px, py, CHIP, 0.85)
				elseif dist < edge + rim then
					blendColor(buf, size, px, py, CHIP_RIM, 0.55)
				end
			end
		end
		checkpoint()
	end
end

@native
local function scratchLine(buf: buffer, size: number, rng: Random, lengthMin: number, lengthMax: number, alphaMin: number, alphaMax: number, segments: number, color: { number })
	local x, y = rng:NextNumber() * size, rng:NextNumber() * size
	local angle = rng:NextNumber(0, math.pi * 2)
	local segmentLength = size * rng:NextNumber(lengthMin, lengthMax) / segments
	local alpha = rng:NextNumber(alphaMin, alphaMax)
	local thick = rng:NextNumber() < 0.2
	local pixelSteps = math.max(1, math.ceil(segmentLength))
	local r, g, b = color[1], color[2], color[3]
	for segment = 0, segments - 1 do
		angle += rng:NextNumber(-0.12, 0.12)
		local dx = math.cos(angle) * segmentLength / pixelSteps
		local dy = math.sin(angle) * segmentLength / pixelSteps
		local taper = math.sin(math.pi * (segment + 0.5) / segments) ^ 0.5
		for _ = 1, pixelSteps do
			x += dx
			y += dy
			local px, py = math.floor(x), math.floor(y)
			blend(buf, size, px, py, r, g, b, alpha * taper)
			if thick then
				blend(buf, size, px + 1, py, r, g, b, alpha * taper * 0.6)
			end
		end
	end
end

@native
local function paintScratches(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear ^ 1.4 * 150)
	for index = 1, count do
		scratchLine(buf, size, layerRng(seed, LAYER_SCRATCH, index), 0.015, 0.04 + 0.12 * wear, 0.35, 0.8, SCRATCH_SEGMENTS, SCRATCH)
		if index % 10 == 0 then
			checkpoint()
		end
	end
end

@native
local function paintMicroScratches(buf: buffer, size: number, seed: number, wear: number)
	local count = math.floor(wear * 220)
	for index = 1, count do
		scratchLine(buf, size, layerRng(seed, LAYER_MICRO, index), 0.004, 0.014, 0.12, 0.3, 4, SCRATCH)
		if index % 40 == 0 then
			checkpoint()
		end
	end
end

local LAYERS = {
	paintBase,
	paintRust,
	paintBlotches,
	paintSmudges,
	paintDust,
	paintChips,
	paintScratches,
	paintMicroScratches,
}

WearPainter.seedFrom = seedFrom

function WearPainter.paint(seed: number, float: number, size: number, yieldFn: (() -> ())?): buffer
	yielder = yieldFn
	deadline = os.clock() + BUDGET
	local buf = buffer.create(size * size * 4)
	for _, layer in LAYERS do
		layer(buf, size, seed, float)
		checkpoint()
	end
	yielder = nil
	return buf
end

return WearPainter
