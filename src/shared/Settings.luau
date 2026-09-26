-- every player setting: its section, how the settings window shows it and its default. saved with the player's
-- data on the server (so settings follow the player) and replicated to their client.
-- kinds: "toggle" (boolean), "choice" (one of options[].value), "tiers" (list of tier ids, the auto-sell picker),
-- "cases" (up to MAX_FAVORITE_CASES case ids, the favorites on the cases page). hidden = true keeps a setting out of
-- the settings window (it is changed somewhere else).
--
-- api: Settings.list, Settings.sections (ordered names), Settings.sectionInfo[name] -> { description },
-- Settings.get(id) -> def?, Settings.defaults() -> { [id]: value },
-- Settings.resolve(saved?) -> saved values with defaults filled in, Settings.clean(id, value) -> value? (nil when
-- the value is not allowed, used by the server to validate), Settings.shouldAutoSell(settings, item) -> boolean

local Shared = script.Parent
local Condition = require(Shared.Modifiers.Condition)
local Serial = require(Shared.Modifiers.Serial)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Tiers = require(Shared.Items.Tiers)
local Traits = require(Shared.Modifiers.Traits)
local CaseRegistry = require(Shared.Cases.CaseRegistry)

export type Option = { value: any, label: string }

export type Def = {
	id: string,
	section: string,
	kind: string,
	label: string,
	description: string?,
	default: any,
	options: { Option }?,
	hidden: boolean?,
}

local Settings = {}

Settings.MAX_FAVORITE_CASES = 5

Settings.sections = { "Gameplay", "Auto-sell", "Trading", "Interface", "Graphics", "Audio", "Notifications", "Advanced" }

Settings.sectionInfo = {
	Gameplay = { description = "Opening cases, auto-open and the games." },
	["Auto-sell"] = { description = "Sell new unboxes you don't want the moment they drop." },
	Trading = { description = "Who can trade with you." },
	Interface = { description = "Menu size and what the screen shows." },
	Graphics = { description = "Effects and overheads. Turn things off for better performance." },
	Audio = { description = "Sound effects." },
	Notifications = { description = "Which pop-ups you see." },
	Advanced = { description = "Extra detail for players who want every number." },
}

-- tiers that auto-sell can pick. divine never auto-sells.
Settings.autoSellTiers = {}
for _, tier in Tiers.list do
	if tier.id ~= "divine" then
		table.insert(Settings.autoSellTiers, tier.id)
	end
end

Settings.list = {
	{
		id = "quickOpen",
		section = "Gameplay",
		kind = "toggle",
		label = "Quick open",
		description = "Shorter case spin (2.5s instead of 6s).",
		default = false,
	},
	{
		id = "autoOpenDelay",
		section = "Gameplay",
		kind = "choice",
		label = "Auto-open delay",
		description = "How long each item is shown before auto-open buys the next case.",
		default = 1.5,
		options = {
			{ value = 0.5, label = "0.5s" },
			{ value = 1.5, label = "1.5s" },
			{ value = 3, label = "3s" },
			{ value = 5, label = "5s" },
		},
	},
	{
		id = "autoOpenStopAt",
		section = "Gameplay",
		kind = "choice",
		label = "Stop auto-open on",
		description = "Auto-open stops by itself when you unbox this rarity or better.",
		default = 0,
		options = {
			{ value = 0, label = "Never" },
			{ value = 4, label = "Epic+" },
			{ value = 5, label = "Legendary+" },
			{ value = 6, label = "Mythic+" },
			{ value = 7, label = "Exotic+" },
		},
	},
	{
		id = "skipCutscenes",
		section = "Gameplay",
		kind = "toggle",
		label = "Skip cutscenes",
		description = "Skip the Exotic and Divine reveal cutscenes and show the item right away.",
		default = false,
	},
	{
		id = "quickCashGames",
		section = "Gameplay",
		kind = "toggle",
		label = "Quick coinflip and dice",
		description = "Shorter coin flip and dice roll animations.",
		default = false,
	},
	{
		id = "favoriteCases",
		section = "Gameplay",
		kind = "cases",
		label = "Favorite cases",
		default = {},
		hidden = true,
	},
	{
		id = "autoSellTiers",
		section = "Auto-sell",
		kind = "tiers",
		label = "Auto-sell rarities",
		description = "New unboxes of these rarities are sold right away. Items with a trait or a stat tracker are always kept.",
		default = {},
	},
	{
		id = "autoSellKeepMint",
		section = "Auto-sell",
		kind = "toggle",
		label = "Keep Mint and Pristine",
		description = "Never auto-sell items in Mint or Pristine condition.",
		default = true,
	},
	{
		id = "autoSellKeepSerial",
		section = "Auto-sell",
		kind = "toggle",
		label = "Keep special serials",
		description = "Never auto-sell top 100 or pattern serials (#69, #777, #1000...).",
		default = true,
	},
	{
		id = "allowTrades",
		section = "Trading",
		kind = "toggle",
		label = "Accept trade requests",
		description = "When off, nobody can send you new trades. Trades already waiting stay.",
		default = true,
	},
	{
		id = "uiScale",
		section = "Interface",
		kind = "choice",
		label = "Menu size",
		description = "Size of windows and the bottom bar. Try Large on a phone.",
		default = 1,
		options = {
			{ value = 0.9, label = "Small" },
			{ value = 1, label = "Normal" },
			{ value = 1.1, label = "Large" },
			{ value = 1.2, label = "Larger" },
		},
	},
	{
		id = "showIncomeRate",
		section = "Interface",
		kind = "toggle",
		label = "Show passive income",
		description = "Your passive income per minute next to your balance.",
		default = true,
	},
	{
		id = "showOverheads",
		section = "Graphics",
		kind = "toggle",
		label = "Player overheads",
		description = "Names, values and stat trackers above other players.",
		default = true,
	},
	{
		id = "showOwnOverhead",
		section = "Graphics",
		kind = "toggle",
		label = "My overhead",
		description = "Show your own overhead above your character.",
		default = true,
	},
	{
		id = "itemEffects",
		section = "Graphics",
		kind = "toggle",
		label = "Trait effects on avatars",
		description = "Particles and glow on worn items with traits. Turn off for better performance.",
		default = true,
	},
	{
		id = "animatedText",
		section = "Graphics",
		kind = "toggle",
		label = "Animated text",
		description = "Moving trait and rarity text effects in menus.",
		default = true,
	},
	{
		id = "sfxVolume",
		section = "Audio",
		kind = "choice",
		label = "Sound effects",
		default = 1,
		options = {
			{ value = 0, label = "Off" },
			{ value = 0.25, label = "25%" },
			{ value = 0.5, label = "50%" },
			{ value = 0.75, label = "75%" },
			{ value = 1, label = "100%" },
		},
	},
	{
		id = "reelTicks",
		section = "Audio",
		kind = "toggle",
		label = "Case spin ticks",
		description = "Tick sound as items pass the marker.",
		default = true,
	},
	{
		id = "announcements",
		section = "Notifications",
		kind = "toggle",
		label = "Server unbox announcements",
		description = "Pop-ups when other players unbox something big.",
		default = true,
	},
	{
		id = "tradeNotifications",
		section = "Notifications",
		kind = "toggle",
		label = "Trade updates",
		description = "Pop-ups for new trades, and trades accepted, declined or countered.",
		default = true,
	},
	{
		id = "advancedStats",
		section = "Advanced",
		kind = "toggle",
		label = "Advanced stats",
		description = "Exact odds on case items, drop chance, asset id and unbox date in item details.",
		default = false,
	},
} :: { Def }

local byId: { [string]: Def } = {}
for _, def in Settings.list do
	byId[def.id] = def
end

function Settings.get(id: string): Def?
	return byId[id]
end

function Settings.defaults(): { [string]: any }
	local values = {}
	for _, def in Settings.list do
		values[def.id] = if type(def.default) == "table" then table.clone(def.default) else def.default
	end
	return values
end

function Settings.resolve(saved: { [string]: any }?): { [string]: any }
	local values = Settings.defaults()
	for id, value in saved or {} do
		if byId[id] then
			values[id] = value
		end
	end
	return values
end

function Settings.clean(id: any, value: any): any
	local def = type(id) == "string" and byId[id]
	if not def then
		return nil
	end
	if def.kind == "toggle" then
		return if type(value) == "boolean" then value else nil
	elseif def.kind == "choice" then
		for _, option in def.options or {} do
			if option.value == value then
				return value
			end
		end
		return nil
	elseif def.kind == "tiers" then
		if type(value) ~= "table" then
			return nil
		end
		local allowed = {}
		for _, tierId in Settings.autoSellTiers do
			allowed[tierId] = true
		end
		local list, seen = {}, {}
		for _, tierId in value do
			if type(tierId) ~= "string" or not allowed[tierId] then
				return nil
			end
			if not seen[tierId] then
				seen[tierId] = true
				table.insert(list, tierId)
			end
		end
		return list
	elseif def.kind == "cases" then
		if type(value) ~= "table" or #value > Settings.MAX_FAVORITE_CASES then
			return nil
		end
		local list, seen = {}, {}
		for _, caseId in value do
			if type(caseId) ~= "string" or not CaseRegistry.get(caseId) or seen[caseId] then
				return nil
			end
			seen[caseId] = true
			table.insert(list, caseId)
		end
		return list
	end
	return nil
end

-- auto-sell never touches traits, stat trackers or divine items, plus whatever the keep toggles protect
function Settings.shouldAutoSell(settings: { [string]: any }, item): boolean
	local tiers = settings.autoSellTiers
	if type(tiers) ~= "table" or #tiers == 0 then
		return false
	end
	if #Traits.of(item) > 0 or item.tracker then
		return false
	end
	if not table.find(tiers, ItemRegistry.tier(item.assetId).id) then
		return false
	end
	if settings.autoSellKeepMint and item.float < Condition.list[2].max then
		return false
	end
	if settings.autoSellKeepSerial and Serial.label(item.serial) ~= nil then
		return false
	end
	return true
end

return Settings
