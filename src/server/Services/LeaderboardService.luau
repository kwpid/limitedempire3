-- top 100 leaderboards (Shared/Progress/Leaderboards): season SP, career level, inventory value and lifetime stats.
-- scores are written to OrderedDataStores every WRITE_INTERVAL and when a player leaves. one board's top 100 is read
-- every READ_STEP seconds in turn (keeps well inside the datastore read budget) and cached. online players' live
-- scores are merged into the cached list when a client asks, so the boards feel live. if the datastores can't be
-- reached (Studio without api access) the boards fall back to the players in the server.
-- the season board's store name includes the season id, so every season starts with an empty board. it only lists
-- players with Seasons.LEADERBOARD_MIN_SP (Legend) unless all ranks are switched on (admin panel, this server only,
-- mirrored to the ReplicatedStorage attribute "SPBoardAllRanks").
-- remote: Net.functions.GetLeaderboard(board) -> { board, season, minScore, entries = { { rank, userId, name, score } } }
-- api: LeaderboardService:SetAllRanks(on), LeaderboardService:Placement(seasonId, userId) -> (ok, placement?)
-- (final Legend placement in a season's top 100, read once per season and cached; ok is false if the datastore
-- couldn't be read)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Leaderboards = require(Shared.Progress.Leaderboards)
local Net = require(Shared.Net)
local Seasons = require(Shared.Progress.Seasons)
local DataConfig = require(ServerScriptService.Server.Modules.DataConfig)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TOP = 100
local WRITE_INTERVAL = 120
local READ_STEP = 20

type Entry = { rank: number, userId: number, name: string, score: number }

local LeaderboardService = {}

local cache: { [string]: { Entry } } = {}
local names: { [number]: string } = {}
local allRanks = Seasons.LEADERBOARD_ALL_RANKS
local placements: { [number]: { [number]: number } } = {}

for _, board in Leaderboards.list do
	cache[board.id] = {}
end

local function scoreOf(player: Player, boardId: string): number?
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	if boardId == "season" then
		return if data.season and data.season.id == Seasons.current() then data.season.sp else nil
	elseif boardId == "level" then
		return data.career and data.career.xp or nil
	elseif boardId == "value" then
		return LeaderstatsService:GetValue(player)
	end
	local board = Leaderboards.get(boardId)
	return board and board.stat and data.stats and data.stats[board.stat] or nil
end

local function storeName(boardId: string, seasonId: number?): string
	if boardId == "season" then
		return `LB_Season{seasonId or Seasons.current()}_v{DataConfig.Version}`
	end
	return `LB_{boardId}_v{DataConfig.Version}`
end

local function store(boardId: string, seasonId: number?): OrderedDataStore?
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, storeName(boardId, seasonId))
	return if ok then result else nil
end

local function minScore(boardId: string): number
	return if boardId == "season" and not allRanks then Seasons.LEADERBOARD_MIN_SP else 1
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else `User {userId}`
	return names[userId]
end

local function write(player: Player)
	-- read every score before the first yield, the player's data may be released right after they leave
	local scores = {}
	for _, board in Leaderboards.list do
		scores[board.id] = scoreOf(player, board.id)
	end
	for boardId, value in scores do
		local target = if value > 0 then store(boardId) else nil
		if target then
			local ok, err = pcall(target.SetAsync, target, tostring(player.UserId), math.floor(value))
			if not ok then
				warn(`[LeaderboardService] couldn't save {boardId} for {player.Name}: {err}`)
			end
		end
	end
end

local function read(boardId: string)
	local target = store(boardId)
	if not target then
		return
	end
	local ok, pages = pcall(target.GetSortedAsync, target, false, TOP)
	if not ok then
		return
	end
	local entries = {}
	for _, row in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(row.key)
		if userId then
			table.insert(entries, { rank = 0, userId = userId, name = nameOf(userId), score = row.value })
		end
	end
	cache[boardId] = entries
end

-- cached top list with the live scores of everyone online merged in
local function build(boardId: string): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in cache[boardId] do
		byUser[entry.userId] = table.clone(entry)
	end
	for _, player in Players:GetPlayers() do
		local score = scoreOf(player, boardId)
		if score then
			byUser[player.UserId] = { rank = 0, userId = player.UserId, name = player.Name, score = math.floor(score) }
		end
	end
	local list = {}
	local min = minScore(boardId)
	for _, entry in byUser do
		if entry.score >= min then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		if a.score == b.score then
			return a.userId < b.userId
		end
		return a.score > b.score
	end)
	local top = {}
	for rank = 1, math.min(TOP, #list) do
		list[rank].rank = rank
		top[rank] = list[rank]
	end
	return top
end

function LeaderboardService:Get(boardId: string)
	return { board = boardId, season = Seasons.current(), minScore = minScore(boardId), entries = build(boardId) }
end

function LeaderboardService:SetAllRanks(on: boolean)
	allRanks = on
	ReplicatedStorage:SetAttribute("SPBoardAllRanks", on)
end

function LeaderboardService:Placement(seasonId: number, userId: number): (boolean, number?)
	if not placements[seasonId] then
		local target = store("season", seasonId)
		if not target then
			return false, nil
		end
		local ok, pages = pcall(target.GetSortedAsync, target, false, TOP, Seasons.LEADERBOARD_MIN_SP)
		if not ok then
			return false, nil
		end
		local byUser = {}
		for place, row in (pages :: DataStorePages):GetCurrentPage() do
			local id = tonumber(row.key)
			if id then
				byUser[id] = place
			end
		end
		placements[seasonId] = byUser
	end
	return true, placements[seasonId][userId]
end

function LeaderboardService:Init()
	ReplicatedStorage:SetAttribute("SPBoardAllRanks", allRanks)
	Net.functions.GetLeaderboard.OnServerInvoke = function(_, boardId)
		if type(boardId) ~= "string" or not Leaderboards.get(boardId) then
			return nil
		end
		return LeaderboardService:Get(boardId)
	end
	PlayerDataService.Leaving:Connect(function(player)
		task.spawn(write, player)
	end)
end

function LeaderboardService:Start()
	task.spawn(function()
		while true do
			task.wait(WRITE_INTERVAL)
			for _, player in Players:GetPlayers() do
				write(player)
			end
		end
	end)
	local index = 0
	while true do
		index = index % #Leaderboards.list + 1
		read(Leaderboards.list[index].id)
		task.wait(READ_STEP)
	end
end

return LeaderboardService
