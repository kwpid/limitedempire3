-- career xp, season points and quests. everything that counts toward progress reports here:
--   ProgressService:CaseOpened(player, case, item) (CaseService and case battles)
--   ProgressService:Track(player, metric, amount, xp?) (games, selling; see Shared/Progress/Quests for metrics)
-- it pays xp (Shared/Progress/Career, milestones unlock titles and name styles), Season Points
-- (Shared/Progress/SeasonPoints, times the event multiplier) and quest rewards (the daily login calendar lives in
-- DailyService),
-- new daily and weekly quests, the season change (soft reset) and inactivity decay, and sends the progress to the
-- player ("progress" delta) plus toasts (Net.events.ProgressEvent). Level and Rank are mirrored to player
-- attributes for overheads.
-- when a season has ended, the player's first refresh after it pays the end of season rewards (rank title and cash,
-- plus a top 100 title and cash for Legends, placement from LeaderboardService) and soft resets their SP.
-- api: :CaseOpened(player, case, item), :Track(player, metric, amount, xp?), :AddXp(player, amount),
-- :AddSp(player, amount, useMultiplier?), :SetSpMultiplier(value), :GetSpMultiplier(), :ResetQuests(player),
-- :Sync(player) (resend progress after the data editor changed it)

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
local Titles = require(Shared.Titles)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local CosmeticService = require(script.Parent.CosmeticService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BoostService = require(script.Parent.BoostService)

local PREMIUM_CASE_PRICE = 15_000
local CHECK_INTERVAL = 60
-- refreshes in a row the season end waits for the leaderboard (top 100 placement) before paying without it
local PLACEMENT_TRIES = 5

local ProgressService = {}

local spMultiplier = Seasons.SP_MULTIPLIER
local refreshing: { [Player]: boolean } = {}
local placementFailures: { [Player]: number } = {}

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
	data.quests.hourly = data.quests.hourly or {}
	data.quests.daily = data.quests.daily or {}
	data.quests.weekly = data.quests.weekly or {}
	data.quests.done = data.quests.done or {}
	data.metrics = data.metrics or {}
end

local function addXp(player: Player, data, amount: number)
	if amount <= 0 then
		return
	end
	amount *= BoostService:Multiplier(player, "xp")
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
	-- the event multiplier and an sp boost apply to Season Points the player earns (not admin grants)
	local multiplier = if useMultiplier then spMultiplier * BoostService:Multiplier(player, "sp") else 1
	local gained = math.floor(amount * multiplier + 0.5)
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
		PlayerDataService:AddCash(player, math.floor(reward.cash * BoostService:Multiplier(player, "cash")))
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

	for _, set in { data.quests.hourly, data.quests.daily, data.quests.weekly } do
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
	local hour = Quests.hour()
	local per = Quests.PER_DIFFICULTY
	if data.quests.hourly.key ~= hour then
		data.quests.hourly = {
			key = hour,
			ids = Quests.pick(Quests.hourly, hour * 31 + player.UserId, per.hourly),
			progress = {},
			done = {},
		}
	end
	if data.quests.daily.key ~= today then
		data.quests.daily = {
			key = today,
			ids = Quests.pick(Quests.daily, today * 7919 + player.UserId, per.daily),
			progress = {},
			done = {},
		}
	end
	if data.quests.weekly.key ~= week then
		data.quests.weekly = {
			key = week,
			ids = Quests.pick(Quests.weekly, week * 104729 + player.UserId, per.weekly),
			progress = {},
			done = {},
		}
	end
end

-- pays the rewards for the season the player last played and moves them to the current one (soft reset)
local function endSeason(player: Player, data, placement: number?)
	local season = data.season
	local current = Seasons.current()
	local endedId = season.id
	local played = (season.peak or 0) > 0

	if played then
		-- decay up to the day the season ended, so the final rank matches the last day of the season
		local _, endsAt = Seasons.range(endedId)
		if season.lastActiveDay > 0 and endsAt then
			season.sp = Seasons.decay(season.sp, Seasons.today(endsAt) - season.lastActiveDay)
		end
		local rank = Ranks.fromSp(season.sp)
		local cash = Seasons.RANK_REWARDS[rank.tier.id] or 0
		local titles = { Titles.seasonRank(endedId, rank.tier.id) }
		local top = if rank.tier.id == "legend" and placement then Seasons.topReward(placement) else nil
		if top then
			cash += top.cash
			table.insert(titles, 1, Titles.seasonTop(endedId, top.id))
		end
		for _, titleId in titles do
			if Titles.get(titleId) then
				CosmeticService:Unlock(player, "title", titleId)
			end
		end
		if cash > 0 then
			PlayerDataService:AddCash(player, cash)
		end
		season.history[tostring(endedId)] = {
			sp = season.sp,
			peak = season.peak,
			rank = rank.name,
			placement = if top then placement else nil,
		}
		notify(player, "seasonRewards", {
			season = Seasons.name(endedId),
			rank = rank.name,
			placement = if top then placement else nil,
			cash = cash,
			titles = titles,
		})
	end

	season.sp = if played then Seasons.softReset(season.sp) else 0
	season.peak = season.sp
	season.id = current
	season.lastActiveDay = Seasons.today()
	notify(player, "newSeason", { name = Seasons.name(current), sp = season.sp })
end

-- season change and inactivity decay
local function refreshSeason(player: Player, data, placement: number?)
	local season = data.season
	if season.id ~= Seasons.current() then
		endSeason(player, data, placement)
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

end

-- unlocks from every milestone at or below the player's level that they don't have yet, so rewards added to
-- levels they already passed still reach them
local function grantPastMilestones(player: Player, data)
	local level = Career.fromXp(data.career.xp)
	local owned = {
		title = PlayerDataService:GetCosmetics(player, "title").unlocked,
		nameStyle = PlayerDataService:GetCosmetics(player, "nameStyle").unlocked,
	}
	for passed = 1, level do
		local milestone = Career.milestone(passed)
		for _, kind in { "title", "nameStyle" } do
			local id = milestone and milestone[kind]
			if id and not table.find(owned[kind], id) then
				CosmeticService:Unlock(player, kind, id)
			end
		end
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
		track(player, data, "spent", case.price)
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
		data.quests.hourly = {}
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
	if refreshing[player] then
		return
	end
	refreshing[player] = true

	-- a season that ended needs the player's final top 100 placement (a datastore read) before paying rewards
	local placement = nil
	local seasonReady = true
	local data = PlayerDataService:GetData(player)
	if data then
		ensure(data)
		local season = data.season
		if season.id ~= Seasons.current() and (season.peak or 0) >= Seasons.LEADERBOARD_MIN_SP then
			local ok, place = LeaderboardService:Placement(season.id, player.UserId)
			if ok then
				placement = place
			else
				placementFailures[player] = (placementFailures[player] or 0) + 1
				seasonReady = placementFailures[player] > PLACEMENT_TRIES
				if seasonReady then
					warn(
						`[ProgressService] no leaderboard placement for {player.Name}, paying season rewards without it`
					)
				end
			end
		end
	end

	local ok, err = pcall(withData, player, function(current)
		if seasonReady then
			refreshSeason(player, current, placement)
		end
		refreshQuests(player, current)
		grantPastMilestones(player, current)
	end)
	if not ok then
		warn(`[ProgressService] refresh failed for {player.Name}: {err}`)
	end
	refreshing[player] = nil
end

function ProgressService:Sync(player: Player)
	withData(player, function() end)
end

function ProgressService:Init()
	ReplicatedStorage:SetAttribute("SPMultiplier", spMultiplier)
	PlayerDataService.Loaded:Connect(refresh)
	Players.PlayerRemoving:Connect(function(player)
		refreshing[player] = nil
		placementFailures[player] = nil
	end)
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
