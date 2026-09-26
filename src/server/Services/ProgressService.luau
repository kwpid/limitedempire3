-- career xp, season points and quests. everything that counts toward progress reports here:
--   ProgressService:CaseOpened(player, case, item) (CaseService and case battles)
--   ProgressService:Track(player, metric, amount, xp?) (games, selling; see Shared/Progress/Quests for metrics)
-- it pays xp (Shared/Progress/Career, milestones unlock titles and name styles), Season Points
-- (Shared/Progress/SeasonPoints, times the event multiplier) and quest rewards, handles the daily login bonus,
-- new daily and weekly quests, the season change (soft reset) and inactivity decay, and sends the progress to the
-- player ("progress" delta) plus toasts (Net.events.ProgressEvent). Level and Rank are mirrored to player
-- attributes for overheads.
-- api: :CaseOpened(player, case, item), :Track(player, metric, amount, xp?), :AddXp(player, amount),
-- :AddSp(player, amount, useMultiplier?), :SetSpMultiplier(value), :GetSpMultiplier(), :ResetQuests(player)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Career = require(Shared.Progress.Career)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)
local Quests = require(Shared.Progress.Quests)
local Ranks = require(Shared.Progress.Ranks)
local SeasonPoints = require(Shared.Progress.SeasonPoints)
local Seasons = require(Shared.Progress.Seasons)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local CosmeticService = require(script.Parent.CosmeticService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PREMIUM_CASE_PRICE = 15_000
local CHECK_INTERVAL = 60

local ProgressService = {}

local spMultiplier = Seasons.SP_MULTIPLIER

local function notify(player: Player, kind: string, payload: any)
	Net.events.ProgressEvent:FireClient(player, kind, payload)
end

local function push(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	PlayerDataService:Push(player, "progress", {
		career = data.career,
		season = data.season,
		quests = data.quests,
		metrics = data.metrics,
	})
	player:SetAttribute("Level", (Career.fromXp(data.career.xp)))
	player:SetAttribute("Rank", Ranks.fromSp(data.season.sp).name)
end

-- older saves may miss parts of the progress data
local function ensure(data)
	data.career = data.career or { xp = 0 }
	data.season = data.season or {}
	local season = data.season
	season.id = season.id or 0
	season.sp = season.sp or 0
	season.peak = season.peak or season.sp
	season.lastActiveDay = season.lastActiveDay or 0
	season.lastLoginDay = season.lastLoginDay or 0
	season.history = season.history or {}
	data.quests = data.quests or {}
	data.quests.daily = data.quests.daily or {}
	data.quests.weekly = data.quests.weekly or {}
	data.quests.done = data.quests.done or {}
	data.metrics = data.metrics or {}
end

local function addXp(player: Player, data, amount: number)
	if amount <= 0 then
		return
	end
	local before = Career.fromXp(data.career.xp)
	data.career.xp += math.floor(amount)
	local after = Career.fromXp(data.career.xp)
	for level = before + 1, after do
		local milestone = Career.milestone(level)
		local unlocks = {}
		if milestone and milestone.title then
			CosmeticService:Unlock(player, "title", milestone.title)
			table.insert(unlocks, { kind = "title", id = milestone.title })
		end
		if milestone and milestone.nameStyle then
			CosmeticService:Unlock(player, "nameStyle", milestone.nameStyle)
			table.insert(unlocks, { kind = "nameStyle", id = milestone.nameStyle })
		end
		notify(player, "levelUp", { level = level, unlocks = unlocks })
	end
end

local function addSp(player: Player, data, amount: number, useMultiplier: boolean)
	local gained = math.floor(amount * (if useMultiplier then spMultiplier else 1) + 0.5)
	if gained <= 0 then
		return
	end
	local season = data.season
	local before = Ranks.fromSp(season.sp)
	season.sp += gained
	season.peak = math.max(season.peak, season.sp)
	season.lastActiveDay = Seasons.today()
	local after = Ranks.fromSp(season.sp)
	if after.order > before.order then
		notify(player, "rankUp", { name = after.name })
	end
end

local function grant(player: Player, data, quest: Quests.Quest)
	local reward = quest.reward
	addXp(player, data, reward.xp or 0)
	addSp(player, data, reward.sp or 0, true)
	if reward.cash and reward.cash > 0 then
		PlayerDataService:AddCash(player, reward.cash)
	end
	if reward.title then
		CosmeticService:Unlock(player, "title", reward.title)
	end
	notify(player, "quest", { name = quest.name, reward = reward })
end

-- counts a metric toward lifetime totals, today's and this week's quests and achievements
local function track(player: Player, data, metric: string, amount: number)
	if amount <= 0 then
		return
	end
	local isMax = Quests.isMax(metric)
	local metrics = data.metrics
	metrics[metric] = if isMax then math.max(metrics[metric] or 0, amount) else (metrics[metric] or 0) + amount

	for _, set in { data.quests.daily, data.quests.weekly } do
		for _, id in set.ids or {} do
			local quest = Quests.get(id)
			if quest and quest.metric == metric and not set.done[id] then
				set.progress[id] = if isMax
					then math.max(set.progress[id] or 0, amount)
					else (set.progress[id] or 0) + amount
				if set.progress[id] >= quest.goal then
					set.done[id] = true
					grant(player, data, quest)
				end
			end
		end
	end

	for _, quest in Quests.achievements do
		if quest.metric == metric and not data.quests.done[quest.id] and (metrics[metric] or 0) >= quest.goal then
			data.quests.done[quest.id] = true
			grant(player, data, quest)
		end
	end
end

local function refreshQuests(player: Player, data)
	local today = Seasons.today()
	local week = Quests.week(today)
	if data.quests.daily.key ~= today then
		data.quests.daily = {
			key = today,
			ids = Quests.pick(Quests.daily, today * 7919 + player.UserId),
			progress = {},
			done = {},
		}
	end
	if data.quests.weekly.key ~= week then
		data.quests.weekly = {
			key = week,
			ids = Quests.pick(Quests.weekly, week * 104729 + player.UserId),
			progress = {},
			done = {},
		}
	end
end

-- season change (soft reset), inactivity decay and the daily login bonus
local function refreshSeason(player: Player, data)
	local season = data.season
	local current = Seasons.current()
	if season.id ~= current then
		season.history[tostring(season.id)] = { sp = season.sp, peak = season.peak }
		season.sp = Seasons.softReset(season.sp)
		season.peak = season.sp
		season.id = current
		notify(player, "newSeason", { name = Seasons.name(current), sp = season.sp })
	end

	local today = Seasons.today()
	if season.lastActiveDay > 0 then
		local decayed = Seasons.decay(season.sp, today - season.lastActiveDay)
		if decayed < season.sp then
			notify(player, "decay", { lost = season.sp - decayed })
			season.sp = decayed
			-- only days after this one count toward the next decay
			season.lastActiveDay = today - Seasons.GRACE_DAYS
		end
	end

	if season.lastLoginDay ~= today then
		season.lastLoginDay = today
		addSp(player, data, Seasons.DAILY_LOGIN_SP, true)
		addXp(player, data, Career.XP.dailyLogin)
		track(player, data, "logins", 1)
		notify(player, "login", { sp = Seasons.DAILY_LOGIN_SP, xp = Career.XP.dailyLogin })
	end
end

local function withData(player: Player, fn: (any) -> ())
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	ensure(data)
	fn(data)
	push(player)
end

function ProgressService:CaseOpened(player: Player, case, item)
	withData(player, function(data)
		addXp(player, data, Career.XP.case + Career.itemXp(item))
		addSp(player, data, SeasonPoints.forCase(case.price, item), true)
		local tier = ItemRegistry.tier(item.assetId)
		local traits = #Traits.of(item)
		track(player, data, "cases", 1)
		track(player, data, "premiumCases", if case.price >= PREMIUM_CASE_PRICE then 1 else 0)
		track(player, data, "epicPlus", if tier.rank >= 4 then 1 else 0)
		track(player, data, "legendaryPlus", if tier.rank >= 5 then 1 else 0)
		track(player, data, "mythicPlus", if tier.rank >= 6 then 1 else 0)
		track(player, data, "exoticPlus", if tier.rank >= 7 then 1 else 0)
		track(player, data, "divine", if tier.id == "divine" then 1 else 0)
		track(player, data, "traits", if traits > 0 then 1 else 0)
		track(player, data, "stacked", if traits > 1 then 1 else 0)
		track(player, data, "trackers", if item.tracker then 1 else 0)
		track(player, data, "unboxedValue", Valuation.value(item))
	end)
end

function ProgressService:Track(player: Player, metric: string, amount: number, xp: number?)
	withData(player, function(data)
		track(player, data, metric, amount)
		addXp(player, data, xp or 0)
	end)
end

function ProgressService:AddXp(player: Player, amount: number)
	withData(player, function(data)
		addXp(player, data, amount)
	end)
end

function ProgressService:AddSp(player: Player, amount: number, useMultiplier: boolean?)
	withData(player, function(data)
		if amount < 0 then
			data.season.sp = math.max(0, data.season.sp + math.floor(amount))
		else
			addSp(player, data, amount, useMultiplier == true)
		end
	end)
end

function ProgressService:ResetQuests(player: Player)
	withData(player, function(data)
		data.quests.daily = {}
		data.quests.weekly = {}
		refreshQuests(player, data)
	end)
end

function ProgressService:SetSpMultiplier(value: number)
	spMultiplier = value
	ReplicatedStorage:SetAttribute("SPMultiplier", value)
end

function ProgressService:GetSpMultiplier(): number
	return spMultiplier
end

local function refresh(player: Player)
	withData(player, function(data)
		refreshSeason(player, data)
		refreshQuests(player, data)
	end)
end

function ProgressService:Init()
	ReplicatedStorage:SetAttribute("SPMultiplier", spMultiplier)
	PlayerDataService.Loaded:Connect(refresh)
end

function ProgressService:Start()
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
	-- new days, weeks and seasons for players who stay online through them
	while true do
		task.wait(CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(refresh, player)
		end
	end
end

return ProgressService
