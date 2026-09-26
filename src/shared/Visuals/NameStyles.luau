-- name styles for overhead names and chat names, picked in the inventory's Name Styles tab.
-- a player's style is the "NameStyle" attribute on their Player, only the server sets it (CosmeticService).
-- grant says who has a style without unlocking it ("everyone", "admin", "moderator"). everyone has "default".
-- level = n unlocks the style at career level n (Shared/Progress/Career adds it to the milestones), the rest are
-- exclusives given out another way (codes, events, the admin panel).
--
-- to add a style, add an entry. every field but id, name, description and chatColor is optional:
--   color      base text color (white under a gradient)
--   gradient   colors across the name
--   color2     second color for the "pulse" animation
--   animation  the whole name: "none", "shimmer" (a bright band sweeps across), "rainbow" (hues scroll), "pulse"
--              (breathes between color and color2), "flicker" (a neon sign flickering)
--   speed      scales the animation and the letters
--   font       an Enum.Font name ("Arcade", "Creepster", ...), default is the game's display font
--   case       "upper", "lower" or "spaced" (S P A C E D)
--   outline    { color, thickness } drawn around the letters
--   letters    moves each letter on its own: "wave", "bounce", "spin" (letters flip in turn), "shake", "sway",
--              "pulse", "float", "zigzag", "glitch" (letters scramble), "typewriter" (types out, then again). with
--              letters, "rainbow" gives every letter its own hue
-- chat can't animate or outline, it shows chatColor, the font and the case.
-- api: NameStyles.get(id?) -> style (falls back to "default"), NameStyles.list (ordered), NameStyles.exists(id),
-- NameStyles.transform(style, text) -> text with the style's case applied

export type Animation = "none" | "shimmer" | "rainbow" | "pulse" | "flicker"

export type NameStyle = {
	id: string,
	name: string,
	color: Color3,
	color2: Color3?,
	gradient: ColorSequence?,
	animation: Animation,
	speed: number,
	font: string?,
	case: string?,
	outline: { color: Color3, thickness: number }?,
	letters: string?,
	level: number?,
	grant: string?,
	description: string,
	chatColor: Color3,
}

local WHITE = Color3.new(1, 1, 1)

local function band(base: Color3, highlight: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.42, base),
		ColorSequenceKeypoint.new(0.5, highlight),
		ColorSequenceKeypoint.new(0.58, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local function fade(from: Color3, to: Color3): ColorSequence
	return ColorSequence.new(from, to)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- fills the fields most styles leave out
local function style(entry): NameStyle
	entry.color = entry.color or WHITE
	entry.animation = entry.animation or "none"
	entry.speed = entry.speed or 1
	return entry :: NameStyle
end

local LIST: { NameStyle } = {
	style({
		id = "default",
		name = "Default",
		color = rgb(236, 239, 244),
		grant = "everyone",
		description = "Plain white name.",
		chatColor = rgb(236, 239, 244),
	}),

	-- the originals
	style({
		id = "gold",
		name = "Gold",
		gradient = band(rgb(228, 174, 57), rgb(255, 240, 190)),
		animation = "shimmer",
		speed = 0.6,
		description = "A golden shine sweeps across your name.",
		chatColor = rgb(240, 190, 80),
	}),
	style({
		id = "frost",
		name = "Frost",
		gradient = band(rgb(120, 200, 255), rgb(235, 250, 255)),
		animation = "shimmer",
		speed = 0.45,
		description = "Icy blue with a frosty shine.",
		chatColor = rgb(140, 210, 255),
	}),
	style({
		id = "void",
		name = "Void",
		gradient = band(rgb(136, 71, 255), rgb(230, 200, 255)),
		animation = "shimmer",
		speed = 0.35,
		description = "Deep purple with a pale glint.",
		chatColor = rgb(170, 120, 255),
	}),
	style({
		id = "rainbow",
		name = "Rainbow",
		animation = "rainbow",
		speed = 0.25,
		description = "Every color, always moving.",
		chatColor = rgb(255, 130, 220),
	}),

	-- career levels, roughly in order
	style({
		id = "whisper",
		name = "Whisper",
		color = rgb(190, 196, 206),
		font = "AmaticSC",
		case = "lower",
		level = 2,
		description = "Thin, quiet and lowercase.",
		chatColor = rgb(190, 196, 206),
	}),
	style({
		id = "loud",
		name = "Loud",
		font = "LuckiestGuy",
		case = "upper",
		outline = { color = rgb(20, 20, 24), thickness = 2 },
		level = 3,
		description = "BIG, BOLD AND IN CAPS.",
		chatColor = rgb(255, 255, 255),
	}),
	style({
		id = "scribble",
		name = "Scribble",
		color = rgb(90, 150, 255),
		font = "PatrickHand",
		letters = "sway",
		speed = 0.8,
		level = 4,
		description = "Handwritten in blue ink, gently swaying.",
		chatColor = rgb(90, 150, 255),
	}),
	style({
		id = "tidal",
		name = "Tidal",
		gradient = fade(rgb(60, 140, 255), rgb(90, 230, 220)),
		letters = "wave",
		level = 6,
		description = "Letters ripple like a wave.",
		chatColor = rgb(80, 180, 240),
	}),
	style({
		id = "bubblegum",
		name = "Bubblegum",
		color = rgb(255, 130, 200),
		font = "FredokaOne",
		letters = "bounce",
		level = 8,
		description = "Round pink letters that bounce.",
		chatColor = rgb(255, 130, 200),
	}),
	style({
		id = "graffiti",
		name = "Graffiti",
		color = rgb(255, 80, 80),
		font = "PermanentMarker",
		outline = { color = rgb(30, 10, 10), thickness = 1.5 },
		letters = "zigzag",
		speed = 0.6,
		level = 10,
		description = "Spray painted and off kilter.",
		chatColor = rgb(255, 90, 90),
	}),
	style({
		id = "typewriter",
		name = "Typewriter",
		color = rgb(225, 205, 160),
		font = "SpecialElite",
		letters = "typewriter",
		speed = 0.6,
		level = 12,
		description = "Types itself out, over and over.",
		chatColor = rgb(225, 205, 160),
	}),
	style({
		id = "sunset",
		name = "Sunset",
		gradient = fade(rgb(255, 150, 60), rgb(255, 80, 150)),
		animation = "shimmer",
		speed = 0.3,
		level = 14,
		description = "Orange fading into pink.",
		chatColor = rgb(255, 120, 110),
	}),
	style({
		id = "arcade",
		name = "Arcade",
		color = rgb(70, 255, 90),
		font = "Arcade",
		case = "upper",
		outline = { color = rgb(10, 60, 20), thickness = 1.5 },
		animation = "flicker",
		speed = 0.8,
		level = 16,
		description = "Pixel letters on a flickering screen.",
		chatColor = rgb(70, 255, 90),
	}),
	style({
		id = "breeze",
		name = "Breeze",
		color = rgb(140, 230, 150),
		font = "Nunito",
		letters = "float",
		speed = 0.7,
		level = 18,
		description = "Soft green letters drifting in the wind.",
		chatColor = rgb(140, 230, 150),
	}),
	style({
		id = "comic",
		name = "Comic",
		color = rgb(255, 225, 60),
		font = "Bangers",
		case = "upper",
		outline = { color = rgb(0, 0, 0), thickness = 2 },
		letters = "bounce",
		speed = 1.3,
		level = 20,
		description = "POW! Straight out of a comic book.",
		chatColor = rgb(255, 225, 60),
	}),
	style({
		id = "commander",
		name = "Commander",
		color = rgb(170, 185, 120),
		font = "Sarpanch",
		case = "upper",
		outline = { color = rgb(30, 36, 20), thickness = 1 },
		level = 22,
		description = "Stencilled military caps.",
		chatColor = rgb(170, 185, 120),
	}),
	style({
		id = "steel",
		name = "Steel",
		gradient = band(rgb(150, 160, 175), rgb(245, 248, 255)),
		animation = "shimmer",
		speed = 0.5,
		level = 25,
		description = "Brushed steel.",
		chatColor = rgb(175, 185, 200),
	}),
	style({
		id = "heartbeat",
		name = "Heartbeat",
		color = rgb(255, 90, 130),
		color2 = rgb(255, 190, 210),
		animation = "pulse",
		letters = "pulse",
		speed = 1.2,
		level = 28,
		description = "Every letter beats like a heart.",
		chatColor = rgb(255, 110, 145),
	}),
	style({
		id = "astral",
		name = "Astral",
		gradient = band(rgb(170, 190, 255), rgb(255, 255, 255)),
		animation = "shimmer",
		font = "Jura",
		case = "spaced",
		speed = 0.35,
		level = 32,
		description = "S P A C E D   O U T   and starlit.",
		chatColor = rgb(170, 190, 255),
	}),
	style({
		id = "spooky",
		name = "Spooky",
		gradient = fade(rgb(255, 140, 30), rgb(150, 60, 220)),
		font = "Creepster",
		letters = "sway",
		speed = 0.9,
		level = 36,
		description = "Dripping, creeping, swaying.",
		chatColor = rgb(255, 140, 30),
	}),
	style({
		id = "royal",
		name = "Royal",
		gradient = band(rgb(210, 160, 50), rgb(255, 245, 200)),
		animation = "shimmer",
		font = "Fondamento",
		speed = 0.4,
		level = 40,
		description = "Old world gold, fit for a crown.",
		chatColor = rgb(230, 185, 80),
	}),
	style({
		id = "tornado",
		name = "Tornado",
		color = rgb(170, 220, 225),
		case = "upper",
		letters = "spin",
		speed = 0.5,
		level = 45,
		description = "Letters flip over one after another.",
		chatColor = rgb(170, 220, 225),
	}),
	style({
		id = "emerald",
		name = "Emerald",
		gradient = band(rgb(40, 190, 110), rgb(200, 255, 220)),
		animation = "shimmer",
		speed = 0.45,
		level = 50,
		description = "Deep green with a bright glint.",
		chatColor = rgb(70, 210, 130),
	}),
	style({
		id = "hacker",
		name = "Hacker",
		color = rgb(60, 255, 120),
		font = "RobotoMono",
		letters = "glitch",
		speed = 1,
		level = 55,
		description = "Terminal green, scrambling as it decrypts.",
		chatColor = rgb(60, 255, 120),
	}),
	style({
		id = "toxic",
		name = "Toxic",
		color = rgb(170, 255, 40),
		color2 = rgb(60, 200, 20),
		animation = "pulse",
		letters = "wave",
		outline = { color = rgb(20, 50, 10), thickness = 1.5 },
		speed = 0.8,
		level = 60,
		description = "Glowing, bubbling hazard green.",
		chatColor = rgb(170, 255, 40),
	}),
	style({
		id = "neon",
		name = "Neon",
		color = rgb(255, 80, 230),
		outline = { color = rgb(120, 20, 110), thickness = 2 },
		animation = "flicker",
		font = "Michroma",
		speed = 1,
		level = 65,
		description = "A buzzing neon sign.",
		chatColor = rgb(255, 80, 230),
	}),
	style({
		id = "rage",
		name = "Rage",
		color = rgb(255, 60, 50),
		case = "upper",
		outline = { color = rgb(60, 0, 0), thickness = 2 },
		letters = "shake",
		speed = 1,
		level = 70,
		description = "SHAKING WITH FURY.",
		chatColor = rgb(255, 60, 50),
	}),
	style({
		id = "crimson",
		name = "Crimson",
		gradient = band(rgb(200, 30, 50), rgb(255, 190, 170)),
		animation = "shimmer",
		speed = 0.4,
		level = 75,
		description = "Blood red with a hot shine.",
		chatColor = rgb(225, 70, 80),
	}),
	style({
		id = "ocean",
		name = "Ocean",
		gradient = fade(rgb(20, 90, 200), rgb(40, 220, 200)),
		font = "Merriweather",
		letters = "wave",
		speed = 0.5,
		level = 80,
		description = "Deep blue swells.",
		chatColor = rgb(40, 150, 220),
	}),
	style({
		id = "vapor",
		name = "Vapor",
		gradient = fade(rgb(255, 110, 200), rgb(80, 220, 255)),
		font = "Jura",
		case = "spaced",
		letters = "float",
		speed = 0.5,
		level = 90,
		description = "A E S T H E T I C.",
		chatColor = rgb(200, 150, 255),
	}),
	style({
		id = "prismatic",
		name = "Prismatic",
		animation = "rainbow",
		speed = 0.45,
		level = 100,
		description = "Fast shifting colors.",
		chatColor = rgb(180, 150, 255),
	}),
	style({
		id = "inferno",
		name = "Inferno",
		gradient = fade(rgb(255, 210, 60), rgb(230, 40, 20)),
		animation = "flicker",
		letters = "float",
		outline = { color = rgb(70, 10, 0), thickness = 1.5 },
		speed = 1.4,
		level = 125,
		description = "Letters rise and flicker like flames.",
		chatColor = rgb(255, 120, 40),
	}),
	style({
		id = "glacier",
		name = "Glacier",
		gradient = band(rgb(170, 225, 255), rgb(255, 255, 255)),
		animation = "shimmer",
		font = "Michroma",
		case = "upper",
		speed = 0.3,
		level = 150,
		description = "FROZEN SOLID.",
		chatColor = rgb(170, 225, 255),
	}),
	style({
		id = "galaxy",
		name = "Galaxy",
		gradient = band(rgb(110, 60, 220), rgb(120, 220, 255)),
		animation = "shimmer",
		letters = "float",
		speed = 0.4,
		level = 175,
		description = "Drifting through a purple nebula.",
		chatColor = rgb(140, 110, 255),
	}),
	style({
		id = "disco",
		name = "Disco",
		animation = "rainbow",
		letters = "bounce",
		font = "FredokaOne",
		speed = 0.8,
		level = 200,
		description = "Every letter its own color, dancing.",
		chatColor = rgb(255, 170, 60),
	}),
	style({
		id = "midas",
		name = "Midas",
		gradient = band(rgb(230, 170, 40), rgb(255, 255, 220)),
		animation = "shimmer",
		font = "Bodoni",
		case = "upper",
		letters = "pulse",
		outline = { color = rgb(80, 50, 0), thickness = 1 },
		speed = 0.6,
		level = 250,
		description = "EVERYTHING IT TOUCHES TURNS TO GOLD.",
		chatColor = rgb(240, 190, 60),
	}),
	style({
		id = "shadow",
		name = "Shadow",
		color = rgb(40, 40, 48),
		outline = { color = rgb(200, 200, 220), thickness = 1.5 },
		letters = "sway",
		speed = 0.4,
		level = 300,
		description = "Dark letters outlined in pale light.",
		chatColor = rgb(120, 120, 140),
	}),
	style({
		id = "chaos",
		name = "Chaos",
		animation = "rainbow",
		letters = "spin",
		case = "upper",
		outline = { color = rgb(0, 0, 0), thickness = 1.5 },
		speed = 1.2,
		level = 400,
		description = "Spinning rainbow madness.",
		chatColor = rgb(255, 80, 120),
	}),
	style({
		id = "legend",
		name = "Legend",
		gradient = band(rgb(255, 200, 60), rgb(255, 255, 255)),
		animation = "shimmer",
		font = "Fondamento",
		case = "spaced",
		letters = "float",
		outline = { color = rgb(90, 50, 0), thickness = 1.5 },
		speed = 0.5,
		level = 500,
		description = "The final career reward.",
		chatColor = rgb(255, 210, 90),
	}),

	-- exclusives (codes, events, the admin panel)
	style({
		id = "glitch",
		name = "Glitch",
		gradient = fade(rgb(0, 240, 255), rgb(255, 40, 200)),
		animation = "flicker",
		letters = "glitch",
		font = "Code",
		speed = 1.2,
		description = "Corrupted. Exclusive.",
		chatColor = rgb(0, 240, 255),
	}),
	style({
		id = "candy",
		name = "Candy",
		animation = "rainbow",
		letters = "wave",
		font = "FredokaOne",
		speed = 0.6,
		description = "Sweet rainbow letters. Exclusive.",
		chatColor = rgb(255, 150, 200),
	}),
	style({
		id = "matrix",
		name = "Matrix",
		color = rgb(40, 255, 90),
		font = "Code",
		case = "upper",
		letters = "typewriter",
		speed = 1.2,
		description = "WAKE UP. Exclusive.",
		chatColor = rgb(40, 255, 90),
	}),
	style({
		id = "titan",
		name = "Titan",
		gradient = fade(rgb(255, 170, 40), rgb(255, 90, 30)),
		font = "LuckiestGuy",
		case = "upper",
		outline = { color = rgb(40, 15, 0), thickness = 2.5 },
		letters = "shake",
		speed = 0.5,
		description = "HEAVY. Exclusive.",
		chatColor = rgb(255, 150, 40),
	}),
	style({
		id = "elegant",
		name = "Elegant",
		color = rgb(215, 195, 255),
		font = "Garamond",
		letters = "sway",
		speed = 0.3,
		description = "Refined lavender script. Exclusive.",
		chatColor = rgb(215, 195, 255),
	}),
	style({
		id = "starlight",
		name = "Starlight",
		gradient = band(rgb(220, 225, 255), rgb(255, 255, 255)),
		animation = "shimmer",
		font = "Michroma",
		letters = "float",
		outline = { color = rgb(80, 90, 160), thickness = 1 },
		speed = 0.6,
		description = "Soft white light. Exclusive.",
		chatColor = rgb(220, 225, 255),
	}),
}

local byId: { [string]: NameStyle } = {}
for _, entry in LIST do
	assert(not byId[entry.id], `duplicate name style {entry.id}`)
	byId[entry.id] = entry
end

local NameStyles = {}
NameStyles.list = LIST

function NameStyles.get(id: string?): NameStyle
	return (id and byId[id]) or byId.default
end

function NameStyles.exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function NameStyles.transform(entry: NameStyle, text: string): string
	if entry.case == "upper" then
		return string.upper(text)
	elseif entry.case == "lower" then
		return string.lower(text)
	elseif entry.case == "spaced" then
		local letters = {}
		for _, code in utf8.codes(string.upper(text)) do
			table.insert(letters, utf8.char(code))
		end
		return table.concat(letters, " ")
	end
	return text
end

return NameStyles
