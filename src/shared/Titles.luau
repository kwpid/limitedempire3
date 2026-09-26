-- player titles, shown under the name on overheads and picked in the inventory's Titles tab.
-- the first title is always "none" (shows nothing). names are shown in all caps.
-- rough color guide (not enforced): grey for common titles, white for rarer ones, glow is for special titles.
-- glow is a soft colored halo around the text, glowColor can be a single color or a ColorSequence (blend).
-- grant says who has a title without unlocking it: "everyone", "admin" (AdminService admins) or "moderator"
-- (CosmeticService.MODERATOR_USER_IDS). titles without a grant are unlocked (career milestones and achievements
-- in Shared/Progress, events later) and saved on the player. shown above the name on overheads and in chat.
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
local WHITE = Color3.fromRGB(236, 238, 242)
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
		id = "rookie",
		name = "Rookie",
		color = GREY,
		glow = false,
		description = "Reach career level 5.",
	},
	{
		id = "regular",
		name = "Regular",
		color = GREY,
		glow = false,
		description = "Reach career level 10.",
	},
	{
		id = "collector",
		name = "Collector",
		color = GREY,
		glow = false,
		description = "Reach career level 15.",
	},
	{
		id = "hoarder",
		name = "Hoarder",
		color = GREY,
		glow = false,
		description = "Reach career level 20.",
	},
	{
		id = "veteran",
		name = "Veteran",
		color = GREY,
		glow = false,
		description = "Reach career level 25.",
	},
	{
		id = "tycoon",
		name = "Tycoon",
		color = WHITE,
		glow = false,
		description = "Reach career level 30.",
	},
	{
		id = "mogul",
		name = "Mogul",
		color = WHITE,
		glow = false,
		description = "Reach career level 40.",
	},
	{
		id = "elite",
		name = "Elite",
		color = WHITE,
		glow = false,
		description = "Reach career level 50.",
	},
	{
		id = "master",
		name = "Master",
		color = WHITE,
		glow = false,
		description = "Reach career level 75.",
	},
	{
		id = "grandmaster",
		name = "Grandmaster",
		color = WHITE,
		glow = false,
		description = "Reach career level 100.",
	},
	{
		id = "unboxer",
		name = "Unboxer",
		color = GREY,
		glow = false,
		description = "Open 1,000 cases.",
	},
	{
		id = "regular_face",
		name = "Familiar Face",
		color = GREY,
		glow = false,
		description = "Log in on 30 different days.",
	},
	{
		id = "case_addict",
		name = "Case Addict",
		color = WHITE,
		glow = false,
		description = "Open 10,000 cases.",
	},
	{
		id = "no_life",
		name = "No Life",
		color = WHITE,
		glow = false,
		description = "Open 100,000 cases.",
	},
	{
		id = "chosen",
		name = "Chosen",
		color = WHITE,
		glow = false,
		description = "Unbox a Divine item.",
	},
	{
		id = "two_of_a_kind",
		name = "Two of a Kind",
		color = WHITE,
		glow = false,
		description = "Unbox a stacked trait.",
	},
	{
		id = "gladiator",
		name = "Gladiator",
		color = WHITE,
		glow = false,
		description = "Win 100 case battles.",
	},
	{
		id = "know_it_all",
		name = "Know-It-All",
		color = WHITE,
		glow = false,
		description = "Get a 15 streak in Higher or Lower.",
	},
	{
		id = "billionaire",
		name = "Billionaire",
		color = WHITE,
		glow = false,
		description = "Unbox T$1B worth of items.",
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
