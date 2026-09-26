-- text styled after an item trait: shiny and golden get a moving shine, rainbow cycles hues, glitched scrambles
-- letters and flickers between cyan and magenta, void pulses dark purple. items without a trait get plain text.
-- props: trait (trait id or nil), plus any Text props (Text, TextSize, display, ...). TextColor3 is the fallback
-- for items without a trait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Traits = require(ReplicatedStorage.Shared.Modifiers.Traits)
local Text = require(script.Parent.Text)
local clock = require(script.Parent.Parent.Clock)

local e = React.createElement

local RAINBOW_STOPS = 6
local GLITCH_STEP = 0.07
local GLITCH_CHARS = { "#", "%", "&", "@", "?", "!", "/", "\\", "0", "1", "X", "_" }

local function noise(n: number): number
	return (math.sin(n * 12.9898) * 43758.5453) % 1
end

local function sheen(base: Color3, bright: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.4, base),
		ColorSequenceKeypoint.new(0.5, bright),
		ColorSequenceKeypoint.new(0.6, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local function sweep(speed: number, pause: number)
	return clock:map(function(t)
		local phase = (t * speed) % (1 + pause)
		return Vector2.new(math.min(phase, 1) * 2 - 1, 0)
	end)
end

local function rainbowAt(shift: number): ColorSequence
	local keypoints = {}
	for i = 0, RAINBOW_STOPS do
		local hue = (i / RAINBOW_STOPS + shift) % 1
		table.insert(keypoints, ColorSequenceKeypoint.new(i / RAINBOW_STOPS, Color3.fromHSV(hue, 0.7, 1)))
	end
	return ColorSequence.new(keypoints)
end

local SHINY = sheen(Color3.fromRGB(255, 246, 200), Color3.fromRGB(255, 255, 255))
local GOLDEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 132, 24)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 196, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 248, 200)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 196, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 132, 24)),
})
local GLITCH_A = Color3.fromRGB(0, 255, 170)
local GLITCH_B = Color3.fromRGB(255, 0, 90)
local VOID = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 20, 130)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 20, 130)),
})

local function glitchGradient(seed: number)
	return {
		Color = clock:map(function(t)
			local step = math.floor(t / GLITCH_STEP)
			local split = 0.2 + noise(step + seed) * 0.6
			local first, second = GLITCH_A, GLITCH_B
			if noise(step * 1.7 + seed) < 0.5 then
				first, second = GLITCH_B, GLITCH_A
			end
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, first),
				ColorSequenceKeypoint.new(split, first),
				ColorSequenceKeypoint.new(math.min(split + 0.001, 1), second),
				ColorSequenceKeypoint.new(1, second),
			})
		end),
	}
end

local function glitchText(source: string, seed: number)
	return clock:map(function(t)
		local step = math.floor(t / GLITCH_STEP)
		if noise(step * 3.1 + seed) > 0.22 or #source == 0 then
			return source
		end
		local chars = string.split(source, "")
		local count = if noise(step * 5.3 + seed) > 0.6 then 2 else 1
		for i = 1, count do
			local index = math.floor(noise(step * 7.7 + seed + i) * #chars) + 1
			if chars[index] ~= " " then
				chars[index] = GLITCH_CHARS[math.floor(noise(step * 9.1 + seed + i) * #GLITCH_CHARS) + 1]
			end
		end
		return table.concat(chars)
	end)
end

local function TraitText(props)
	local trait = Traits.get(props.trait)
	local seed = React.useMemo(function()
		return math.random() * 1000
	end, {})

	local hostProps = {}
	for key, value in props do
		if key ~= "trait" then
			hostProps[key] = value
		end
	end
	if not trait then
		return e(Text, hostProps)
	end

	hostProps.TextColor3 = Color3.new(1, 1, 1)
	local gradient
	if trait.id == "shiny" then
		gradient = { Color = SHINY, Offset = sweep(0.8, 0.6) }
	elseif trait.id == "golden" then
		gradient = { Color = GOLDEN, Offset = sweep(0.6, 0.3), Rotation = 15 }
		hostProps.TextStrokeColor3 = Color3.fromRGB(90, 55, 0)
		hostProps.TextStrokeTransparency = 0.4
	elseif trait.id == "rainbow" then
		gradient = {
			Color = clock:map(function(t)
				return rainbowAt((t * 0.35) % 1)
			end),
		}
	elseif trait.id == "glitched" then
		gradient = glitchGradient(seed)
		if type(props.Text) == "string" then
			hostProps.Text = glitchText(if props.display then string.upper(props.Text) else props.Text, seed)
		end
	elseif trait.id == "void" then
		gradient = {
			Color = VOID,
			Offset = clock:map(function(t)
				return Vector2.new(math.sin(t * 1.4) * 0.5, 0)
			end),
		}
		hostProps.TextStrokeColor3 = Color3.fromRGB(150, 60, 255)
		hostProps.TextStrokeTransparency = clock:map(function(t)
			return 0.55 + math.sin(t * 2.2) * 0.25
		end)
	else
		hostProps.TextColor3 = trait.uiColor
	end

	local children = table.clone(props.children or {})
	if gradient then
		children.TraitGradient = e("UIGradient", gradient)
	end
	hostProps.children = children
	return e(Text, hostProps)
end

return TraitText
