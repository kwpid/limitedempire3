-- a player name drawn in a name style (Shared.Visuals.NameStyles): font, case, outline, a whole-name effect
-- (shimmer, rainbow, pulse, flicker) and, for styles with letters, every letter moving on its own (wave, bounce,
-- spin, shake, sway, pulse, float, zigzag, glitch, typewriter). with letters, each letter sits in a slot sized to
-- the real glyph and the visible copy moves inside it, so moving letters never push the rest of the name around.
-- everything holds still when the "animatedText" setting is off.
-- props: text, styleId, textSize?, size, position?, anchorPoint?, layoutOrder?, alignment?, strokeTransparency?

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)
local Theme = require(script.Parent.Parent.Theme)
local clock = require(script.Parent.Parent.Clock)
local useSetting = require(script.Parent.Parent.Hooks.useSetting)

local e = React.createElement

local STILL = React.createBinding(0.35)
local RAINBOW_STOPS = 6
local GLITCH_CHARS = { "#", "%", "&", "@", "?", "!", "/", "\\", "0", "1", "X", "_", "$", "*" }
local WHITE = Color3.new(1, 1, 1)

local fonts: { [string]: Font } = {}
local function fontFor(style: NameStyles.NameStyle): Font
	local name = style.font
	if not name then
		return Theme.display(Enum.FontWeight.Bold)
	end
	if not fonts[name] then
		local ok, font = pcall(function()
			return Font.fromEnum((Enum.Font :: any)[name])
		end)
		fonts[name] = if ok then font else Theme.display(Enum.FontWeight.Bold)
	end
	return fonts[name]
end

local function noise(n: number): number
	return (math.sin(n * 12.9898) * 43758.5453) % 1
end

local function rainbowAt(shift: number): ColorSequence
	local keypoints = {}
	for i = 0, RAINBOW_STOPS do
		local hue = (i / RAINBOW_STOPS + shift) % 1
		table.insert(keypoints, ColorSequenceKeypoint.new(i / RAINBOW_STOPS, Color3.fromHSV(hue, 0.65, 1)))
	end
	return ColorSequence.new(keypoints)
end

-- the color of a ColorSequence at x (0 to 1)
local function sample(sequence: ColorSequence, x: number): Color3
	local points = sequence.Keypoints
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if x <= b.Time then
			local span = b.Time - a.Time
			return if span > 0 then a.Value:Lerp(b.Value, (x - a.Time) / span) else b.Value
		end
	end
	return points[#points].Value
end

local function pulseAmount(t: number, speed: number): number
	return (math.sin(t * speed * math.pi * 2) + 1) / 2
end

-- mostly lit, now and then a quick dim, like a neon sign
local function flickerAt(t: number, speed: number): number
	local n = noise(math.floor(t * 12 * speed))
	return if n > 0.93 then 0.65 elseif n > 0.86 then 0.3 else 0
end

local function outlineFor(style: NameStyles.NameStyle)
	local outline = style.outline
	if not outline then
		return nil
	end
	return e("UIStroke", {
		Color = outline.color,
		Thickness = outline.thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

-- the whole name in one label (styles without letters)
local function wholeLabel(props, style: NameStyles.NameStyle, time, text: string)
	local gradient = nil
	if style.animation == "rainbow" then
		gradient = e("UIGradient", {
			Color = time:map(function(t)
				return rainbowAt((t * style.speed) % 1)
			end),
		})
	elseif style.gradient and style.animation == "shimmer" then
		gradient = e("UIGradient", {
			Color = style.gradient,
			Offset = time:map(function(t)
				return Vector2.new(((t * style.speed) % 1) * 2.4 - 1.2, 0)
			end),
		})
	elseif style.gradient then
		gradient = e("UIGradient", { Color = style.gradient })
	end

	return e("TextLabel", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		Text = text,
		FontFace = fontFor(style),
		TextSize = props.textSize or 20,
		TextColor3 = if style.animation == "pulse" and style.color2
			then time:map(function(t)
				return style.color:Lerp(style.color2 :: Color3, pulseAmount(t, style.speed))
			end)
			else style.color,
		TextTransparency = if style.animation == "flicker"
			then time:map(function(t)
				return flickerAt(t, style.speed)
			end)
			else 0,
		TextStrokeTransparency = if style.outline then 1 else (props.strokeTransparency or 0.55),
		TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, {
		Gradient = gradient,
		Outline = outlineFor(style),
	})
end

-- offset (x, y), rotation and scale of letter i (0 based) of count at time t
local function motion(kind: string, t: number, i: number, count: number, speed: number, size: number)
	local amp = size * 0.13
	if kind == "wave" then
		return 0, math.sin(t * speed * 4 - i * 0.6) * amp, 0, 1
	elseif kind == "bounce" then
		return 0, -math.abs(math.sin(t * speed * 3 - i * 0.45)) * amp * 1.3, 0, 1
	elseif kind == "float" then
		return 0, math.sin(t * speed * 2 - i * 0.5) * amp * 0.8, math.sin(t * speed * 1.5 - i * 0.5) * 6, 1
	elseif kind == "sway" then
		return 0, 0, math.sin(t * speed * 2.5 - i * 0.5) * 14, 1
	elseif kind == "zigzag" then
		local side = if i % 2 == 0 then 1 else -1
		local s = math.sin(t * speed * 3)
		return 0, side * s * amp * 0.7, side * s * 8, 1
	elseif kind == "shake" then
		local step = math.floor(t * 30 * speed)
		return (noise(step + i * 7.1) - 0.5) * amp * 0.8, (noise(step + i * 3.7 + 50) - 0.5) * amp * 0.8, 0, 1
	elseif kind == "spin" then
		-- one letter after another does a full flip, then they all rest
		local phase = (t * speed * 0.5 - i * 0.06) % 1
		local rotation = if phase < 0.25 then (1 - (1 - phase / 0.25) ^ 3) * 360 else 0
		return 0, 0, rotation, 1
	elseif kind == "pulse" then
		return 0, 0, 0, 1 + 0.2 * math.max(0, math.sin(t * speed * 4 - i * 0.5))
	elseif kind == "glitch" then
		local glitching = noise(math.floor(t * 10 * speed) + i * 3.3) > 0.82
		return if glitching then (noise(t * 40 + i) - 0.5) * amp else 0, 0, 0, 1
	end
	return 0, 0, 0, 1
end

local function Letter(props)
	local style: NameStyles.NameStyle = props.style
	local time, i, count, char, size = props.time, props.index, props.count, props.char, props.textSize
	local kind = style.letters :: string
	local x = if count > 1 then i / (count - 1) else 0.5

	local color: any = style.color
	if style.animation == "rainbow" then
		color = time:map(function(t)
			return Color3.fromHSV((x * 0.8 + t * style.speed * 0.25) % 1, 0.65, 1)
		end)
	elseif style.gradient and style.animation == "shimmer" then
		local base = sample(style.gradient, x)
		color = time:map(function(t)
			local sweep = ((t * style.speed * 0.6) % 1.6) - 0.3
			return base:Lerp(WHITE, math.max(0, 1 - math.abs(x - sweep) * 5) * 0.7)
		end)
	elseif style.gradient then
		color = sample(style.gradient, x)
	elseif style.animation == "pulse" and style.color2 then
		color = time:map(function(t)
			return style.color:Lerp(style.color2 :: Color3, pulseAmount(t - i * 0.08, style.speed))
		end)
	end

	local transparency: any = 0
	if kind == "typewriter" then
		-- types out a letter at a time, holds, blanks, again
		local step = 0.12 / style.speed
		local cycle = count * step + 1.6
		transparency = time:map(function(t)
			return if (t % cycle) >= i * step then 0 else 1
		end)
	elseif style.animation == "flicker" then
		transparency = time:map(function(t)
			return flickerAt(t + i * 0.37, style.speed)
		end)
	end

	local text: any = char
	if kind == "glitch" and char ~= " " then
		text = time:map(function(t)
			local step = math.floor(t * 10 * style.speed)
			if noise(step + i * 3.3) > 0.82 then
				return GLITCH_CHARS[math.floor(noise(step * 1.7 + i) * #GLITCH_CHARS) + 1]
			end
			return char
		end)
	end

	local moved = time:map(function(t)
		return { motion(kind, t, i, count, style.speed, size) }
	end)
	local font = fontFor(style)

	-- the slot holds the real width, the glyph inside it moves
	return e("TextLabel", {
		LayoutOrder = i,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = char,
		FontFace = font,
		TextSize = size,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}, {
		Glyph = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = moved:map(function(m)
				return UDim2.new(0.5, m[1], 0.5, m[2])
			end),
			Rotation = moved:map(function(m)
				return m[3]
			end),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = font,
			TextSize = size,
			TextColor3 = color,
			TextTransparency = transparency,
			TextStrokeTransparency = if style.outline then 1 else (props.strokeTransparency or 0.55),
		}, {
			Scale = e("UIScale", {
				Scale = moved:map(function(m)
					return m[4]
				end),
			}),
			Outline = outlineFor(style),
		}),
	})
end

local function NameLabel(props)
	local style = NameStyles.get(props.styleId)
	local animated = useSetting("animatedText") ~= false
	local time = if animated then clock else STILL
	local text = NameStyles.transform(style, props.text or "")

	if not style.letters then
		return wholeLabel(props, style, time, text)
	end

	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	local alignment = props.alignment or Enum.TextXAlignment.Center
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if alignment == Enum.TextXAlignment.Left
				then Enum.HorizontalAlignment.Left
				elseif alignment == Enum.TextXAlignment.Right then Enum.HorizontalAlignment.Right
				else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, char in chars do
		children["Letter" .. index] = e(Letter, {
			style = style,
			time = time,
			index = index - 1,
			count = #chars,
			char = char,
			textSize = props.textSize or 20,
			strokeTransparency = props.strokeTransparency,
		})
	end

	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
	}, children)
end

return React.memo(NameLabel)
