-- name styles for overhead names and chat names, picked in the inventory's Name Styles tab.
-- a player's style is the "NameStyle" attribute on their Player, only the server sets it (CosmeticService).
-- grant says who has a style without unlocking it ("everyone", "admin", "moderator"), styles without a grant are
-- unlocked through quests and events later and saved on the player. chat can't animate, it uses chatColor.
-- to add a style, add an entry: color is the base text color, gradient (optional) tints across the name,
-- animation is "none", "shimmer" (a bright band sweeps across) or "rainbow" (hues scroll), speed scales the animation.
-- api: NameStyles.get(id?) -> style (falls back to "default"), NameStyles.list (ordered), NameStyles.exists(id)

export type Animation = "none" | "shimmer" | "rainbow"

export type NameStyle = {
	id: string,
	name: string,
	color: Color3,
	gradient: ColorSequence?,
	animation: Animation,
	speed: number,
	grant: string?,
	description: string,
	chatColor: Color3,
}

local function band(base: Color3, highlight: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.42, base),
		ColorSequenceKeypoint.new(0.5, highlight),
		ColorSequenceKeypoint.new(0.58, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local LIST: { NameStyle } = {
	{
		id = "default",
		name = "Default",
		color = Color3.fromRGB(236, 239, 244),
		animation = "none",
		speed = 0,
		grant = "everyone",
		description = "Plain white name.",
		chatColor = Color3.fromRGB(236, 239, 244),
	},
	{
		id = "gold",
		name = "Gold",
		color = Color3.new(1, 1, 1),
		gradient = band(Color3.fromRGB(228, 174, 57), Color3.fromRGB(255, 240, 190)),
		animation = "shimmer",
		speed = 0.6,
		description = "A golden shine sweeps across your name.",
		chatColor = Color3.fromRGB(240, 190, 80),
	},
	{
		id = "frost",
		name = "Frost",
		color = Color3.new(1, 1, 1),
		gradient = band(Color3.fromRGB(120, 200, 255), Color3.fromRGB(235, 250, 255)),
		animation = "shimmer",
		speed = 0.45,
		description = "Icy blue with a frosty shine.",
		chatColor = Color3.fromRGB(140, 210, 255),
	},
	{
		id = "void",
		name = "Void",
		color = Color3.new(1, 1, 1),
		gradient = band(Color3.fromRGB(136, 71, 255), Color3.fromRGB(230, 200, 255)),
		animation = "shimmer",
		speed = 0.35,
		description = "Deep purple with a pale glint.",
		chatColor = Color3.fromRGB(170, 120, 255),
	},
	{
		id = "rainbow",
		name = "Rainbow",
		color = Color3.new(1, 1, 1),
		animation = "rainbow",
		speed = 0.25,
		description = "Every color, always moving.",
		chatColor = Color3.fromRGB(255, 130, 220),
	},
}

local byId: { [string]: NameStyle } = {}
for _, style in LIST do
	byId[style.id] = style
end

local NameStyles = {}
NameStyles.list = LIST

function NameStyles.get(id: string?): NameStyle
	return (id and byId[id]) or byId.default
end

function NameStyles.exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return NameStyles
