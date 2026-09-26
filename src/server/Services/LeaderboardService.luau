-- top 100 leaderboards: "season" (Season Points this season), "level" (career xp) and "value" (inventory value).
-- scores are written to OrderedDataStores every WRITE_INTERVAL and when a player leaves; the top 100 of each board
-- is read every READ_INTERVAL and cached. online players' live scores are merged into the cached list when a client
-- asks, so the board feels live without extra datastore calls. if the datastores can't be reached (Studio without
-- api access) the boards fall back to the players in the server.
-- the season board's store name includes the season id, so every season starts with an empty board.
-- remote: Net.functions.GetLeaderboard(board) -> { entries = { { rank, userId, name, score } }, board, season }

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Seasons = require(Shared.Progress.Seasons)
local DataConfig = require(ServerScriptService.Server.Modules.DataConfig)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TOP = 100
local WRITE_INTERVAL = 120
local READ_INTERVAL = 90

type Entry = { rank: number, userId: number, name: string, score: number }

local LeaderboardService = {}

local BOARDS: { [string]: (Player) -> number? } = {
	season = function(player)
		local data = PlayerDataService:GetData(player)
		return data and data.season and data.season.id == Seasons.current() and data.season.sp or nil
	end,
	level = function(player)
		local data = PlayerDataService:GetData(player)
		return data and data.career and data.career.xp or nil
	end,
	value = function(player)
		return if PlayerDataService:GetData(player) then LeaderstatsService:GetValue(player) else nil
	end,
}

local cache: { [string]: { Entry } } = { season = {}, level = {}, value = {} }
local names: { [number]: string } = {}

local function storeName(board: string): string
	if board == "season" then
		return `LB_Season{Seasons.current()}_v{DataConfig.Version}`
	end
	return `LB_{board}_v{DataConfig.Version}`
end

local function store(board: string): OrderedDataStore?
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, storeName(board))
	return if ok then result else nil
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
	for board, score in BOARDS do
		scores[board] = score(player)
	end
	for board, value in scores do
		local target = store(board)
		if target then
			local ok, err = pcall(target.SetAsync, target, tostring(player.UserId), math.floor(value :: number))
			if not ok then
				warn(`[LeaderboardService] couldn't save {board} for {player.Name}: {err}`)
			end
		end
	end
end

local function read(board: string)
	local target = store(board)
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
	cache[board] = entries
end

-- cached top list with the live scores of everyone online merged in
local function build(board: string): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in cache[board] do
		byUser[entry.userId] = table.clone(entry)
	end
	for _, player in Players:GetPlayers() do
		local score = BOARDS[board](player)
		if score then
			byUser[player.UserId] = { rank = 0, userId = player.UserId, name = player.Name, score = math.floor(score) }
		end
	end
	local list = {}
	for _, entry in byUser do
		if entry.score > 0 then
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

function LeaderboardService:Get(board: string)
	return { board = board, season = Seasons.current(), entries = build(board) }
end

function LeaderboardService:Init()
	Net.functions.GetLeaderboard.OnServerInvoke = function(_, board)
		if type(board) ~= "string" or not BOARDS[board] then
			return nil
		end
		return LeaderboardService:Get(board)
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
	while true do
		for board in BOARDS do
			read(board)
		end
		task.wait(READ_INTERVAL)
	end
end

return LeaderboardService
