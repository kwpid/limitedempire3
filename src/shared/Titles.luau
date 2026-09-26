-- player titles, shown under the name on overheads and picked in the inventory's Titles tab.
-- the first title is always "none" (shows nothing). names are shown in all caps.
-- rough color guide (not enforced): grey for common titles, white for rarer ones, glow is for special titles.
-- glow is a soft colored halo around the text, glowColor can be a single color or a ColorSequence (blend).
-- grant says who has a title without unlocking it: "everyone", "admin" (AdminService admins) or "moderator"
-- (CosmeticService.MODERATOR_USER_IDS). titles without a grant are unlocked through quests and events later and
-- saved on the player. shown above the name on overheads and in front of chat messages.
--
-- api: Titles.list (display order), Titles.get(id) -> Title?, Titles.NONE ("none")

export type Title = {
	id: string,
	name: string,
	color: Color3,
	glow: boolean,
	glowColor: (Color3 | ColorSequence)?,
	grant: string?,
	description: string,
}

local GREY = Color3.fromRGB(150, 155, 160)
local GREEN = Color3.fromRGB(90, 235, 120)

local LIST: { Title } = {
	{
		id = "none",
		name = "None",
		color = GREY,
		glow = false,
		grant = "everyone",
		description = "No title.",
	},
	{
		id = "noob",
		name = "Noob",
		color = GREY,
		glow = false,
		grant = "everyone",
		description = "Everyone starts somewhere.",
	},
	{
		id = "developer",
		name = "Developer",
		color = GREEN,
		glow = true,
		glowColor = ColorSequence.new(Color3.fromRGB(60, 255, 120), Color3.fromRGB(60, 170, 255)),
		grant = "admin",
		description = "Makes the game.",
	},
	{
		id = "moderator",
		name = "Moderator",
		color = GREEN,
		glow = true,
		glowColor = Color3.fromRGB(60, 255, 120),
		grant = "moderator",
		description = "Keeps the game running smoothly.",
	},
}

local byId: { [string]: Title } = {}
for _, title in LIST do
	assert(not byId[title.id], `duplicate title id "{title.id}"`)
	byId[title.id] = title
end

local Titles = {}
Titles.list = LIST
Titles.NONE = "none"

function Titles.get(id: string?): Title?
	return id and byId[id] or nil
end

return Titles
