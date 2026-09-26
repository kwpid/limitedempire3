-- case battles. a lobby has a list of cases (repeats allowed, up to MAX_ROUNDS) and 2 to 4 seats. every player
-- pays the total case cost when they take a seat (refunded if they leave or the lobby closes before it starts).
-- the host can put bots in empty seats, or start early and let bots fill the rest (solo play is a lobby with only
-- the host). when it starts, every seat opens the same cases round by round and the highest total value wins every
-- item opened (ties are picked at random). bots use the same case odds; when a bot wins, the items are destroyed.
-- the server rolls the whole battle at once and hands out the items right away (so nothing is lost if someone
-- leaves mid battle); clients play the rounds back as an animation.
--
-- remotes: Net.functions.BattleAction(action, payload) -> { ok, err?, data? } with actions
--   "create" { cases = { caseId }, seats }, "join" { id }, "leave", "addBot", "start"
-- Net.events.BattleUpdate:FireClient(player, kind, payload):
--   "lobbies" { summary } (to everyone, open lobbies), "lobby" state? (to its members, nil when they left),
--   "battle" result (to its members when it starts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Valuation = require(Shared.Modifiers.Valuation)
local ItemFactory = require(ServerScriptService.Server.Modules.ItemFactory)
local ItemModelService = require(script.Parent.ItemModelService)
local LuckService = require(script.Parent.LuckService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MAX_ROUNDS = 10
local MIN_SEATS, MAX_SEATS = 2, 4
local BOT_NAMES = { "Bot Blox", "Bot Noob", "Bot Tix", "Bot Crown", "Bot Valk", "Bot Sparkle", "Bot Domino" }

type Seat = { userId: number?, name: string, bot: boolean }
type Lobby = {
	id: number,
	host: Player,
	cases: { string },
	cost: number,
	seats: { Seat | false },
	players: { [Player]: number },
	started: boolean,
}

local CaseBattleService = {}

local lobbies: { [number]: Lobby } = {}
local playerLobby: { [Player]: Lobby } = {}
local nextId = 0
local rng = Random.new()

local function fail(err: string): Types.Result<any>
	return { ok = false, err = err }
end

local function summary(lobby: Lobby)
	local seats = {}
	for index, seat in lobby.seats do
		seats[index] = if seat then { name = seat.name, bot = seat.bot, userId = seat.userId } else false
	end
	return {
		id = lobby.id,
		host = lobby.host.Name,
		hostUserId = lobby.host.UserId,
		cases = lobby.cases,
		cost = lobby.cost,
		seats = seats,
		seatCount = #lobby.seats,
		started = lobby.started,
	}
end

local function broadcastLobbies()
	local list = {}
	for _, lobby in lobbies do
		if not lobby.started then
			table.insert(list, summary(lobby))
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	Net.events.BattleUpdate:FireAllClients("lobbies", list)
end

local function sendLobby(lobby: Lobby)
	local data = summary(lobby)
	for player in lobby.players do
		Net.events.BattleUpdate:FireClient(player, "lobby", data)
	end
end

local function closeLobby(lobby: Lobby, refund: boolean)
	lobbies[lobby.id] = nil
	for player in lobby.players do
		if refund then
			PlayerDataService:AddCash(player, lobby.cost)
		end
		playerLobby[player] = nil
		Net.events.BattleUpdate:FireClient(player, "lobby", nil)
	end
	broadcastLobbies()
end

local function openSeat(lobby: Lobby): number?
	for index, seat in lobby.seats do
		if not seat then
			return index
		end
	end
	return nil
end

local function botName(lobby: Lobby): string
	local used = {}
	for _, seat in lobby.seats do
		if seat then
			used[seat.name] = true
		end
	end
	for _, name in BOT_NAMES do
		if not used[name] then
			return name
		end
	end
	return "Bot"
end

-- rolls every seat for every round, picks the winner, hands out the items
local function run(lobby: Lobby)
	lobby.started = true
	broadcastLobbies()

	local seatPlayers: { [number]: Player } = {}
	for player, index in lobby.players do
		seatPlayers[index] = player
	end

	local rounds = {}
	local totals = {}
	local allItems = {}
	for index = 1, #lobby.seats do
		totals[index] = 0
	end
	for round, caseId in lobby.cases do
		local results = {}
		for index, seat in lobby.seats do
			local player = seatPlayers[index]
			local luck = if player then LuckService:Get(player) else 1
			local assetId = ItemFactory.roll(caseId, luck)
			local item = ItemFactory.create(assetId, caseId, luck, player)
			ItemModelService:Prepare(assetId)
			local value = Valuation.value(item)
			totals[index] += value
			results[index] = item
			table.insert(allItems, item)
		end
		rounds[round] = results
	end

	local best = -1
	local winners = {}
	for index, total in totals do
		if total > best then
			best = total
			winners = { index }
		elseif total == best then
			table.insert(winners, index)
		end
	end
	local winner = winners[rng:NextInteger(1, #winners)]
	local winnerPlayer = seatPlayers[winner]
	if winnerPlayer and winnerPlayer.Parent then
		for _, item in allItems do
			-- items a bot opened have no original owner, the winner is the first real one
			item.originalOwner = item.originalOwner or { userId = winnerPlayer.UserId, name = winnerPlayer.Name }
			PlayerDataService:AddItem(winnerPlayer, item)
		end
	end
	for player, index in lobby.players do
		PlayerDataService:AddStats(player, { battles = 1, battlesWon = if index == winner then 1 else 0 })
	end

	local result = {
		lobby = summary(lobby),
		rounds = rounds,
		totals = totals,
		winner = winner,
	}
	for player in lobby.players do
		playerLobby[player] = nil
		Net.events.BattleUpdate:FireClient(player, "battle", result)
		Net.events.BattleUpdate:FireClient(player, "lobby", nil)
	end
	lobbies[lobby.id] = nil
end

local function readCases(value: any): ({ string }?, number?)
	if type(value) ~= "table" or #value == 0 or #value > MAX_ROUNDS then
		return nil, nil
	end
	local cost = 0
	for _, caseId in value do
		local case = type(caseId) == "string" and CaseRegistry.get(caseId)
		if not case then
			return nil, nil
		end
		cost += case.price
	end
	return table.clone(value), cost
end

local ACTIONS = {
	create = function(player: Player, payload: any): Types.Result<any>
		if playerLobby[player] then
			return fail("You're already in a lobby")
		end
		local cases, cost = readCases(type(payload) == "table" and payload.cases)
		if not cases then
			return fail(`Pick 1 to {MAX_ROUNDS} cases`)
		end
		local seats = type(payload) == "table" and payload.seats
		if type(seats) ~= "number" or seats ~= math.floor(seats) or seats < MIN_SEATS or seats > MAX_SEATS then
			return fail("Invalid seat count")
		end
		if not PlayerDataService:TrySpend(player, cost :: number) then
			return fail(`Not enough {Config.Currency.Name}`)
		end
		nextId += 1
		local lobby: Lobby = {
			id = nextId,
			host = player,
			cases = cases,
			cost = cost :: number,
			seats = table.create(seats, false),
			players = { [player] = 1 },
			started = false,
		}
		lobby.seats[1] = { userId = player.UserId, name = player.DisplayName, bot = false }
		lobbies[lobby.id] = lobby
		playerLobby[player] = lobby
		sendLobby(lobby)
		broadcastLobbies()
		return { ok = true }
	end,

	join = function(player: Player, payload: any): Types.Result<any>
		if playerLobby[player] then
			return fail("You're already in a lobby")
		end
		local lobby = type(payload) == "table" and lobbies[payload.id]
		if not lobby or lobby.started then
			return fail("That lobby is gone")
		end
		local index = openSeat(lobby)
		if not index then
			return fail("That lobby is full")
		end
		if not PlayerDataService:TrySpend(player, lobby.cost) then
			return fail(`Not enough {Config.Currency.Name}`)
		end
		lobby.seats[index] = { userId = player.UserId, name = player.DisplayName, bot = false }
		lobby.players[player] = index
		playerLobby[player] = lobby
		if not openSeat(lobby) then
			task.spawn(run, lobby)
		else
			sendLobby(lobby)
			broadcastLobbies()
		end
		return { ok = true }
	end,

	leave = function(player: Player): Types.Result<any>
		local lobby = playerLobby[player]
		if not lobby or lobby.started then
			return fail("You're not in a lobby")
		end
		if lobby.host == player then
			closeLobby(lobby, true)
			return { ok = true }
		end
		local index = lobby.players[player]
		lobby.players[player] = nil
		lobby.seats[index] = false
		playerLobby[player] = nil
		PlayerDataService:AddCash(player, lobby.cost)
		Net.events.BattleUpdate:FireClient(player, "lobby", nil)
		sendLobby(lobby)
		broadcastLobbies()
		return { ok = true }
	end,

	addBot = function(player: Player): Types.Result<any>
		local lobby = playerLobby[player]
		if not lobby or lobby.started or lobby.host ~= player then
			return fail("Only the host can add bots")
		end
		local index = openSeat(lobby)
		if not index then
			return fail("The lobby is full")
		end
		lobby.seats[index] = { name = botName(lobby), bot = true }
		if not openSeat(lobby) then
			task.spawn(run, lobby)
		else
			sendLobby(lobby)
			broadcastLobbies()
		end
		return { ok = true }
	end,

	start = function(player: Player): Types.Result<any>
		local lobby = playerLobby[player]
		if not lobby or lobby.started or lobby.host ~= player then
			return fail("Only the host can start")
		end
		while true do
			local index = openSeat(lobby)
			if not index then
				break
			end
			lobby.seats[index] = { name = botName(lobby), bot = true }
		end
		task.spawn(run, lobby)
		return { ok = true }
	end,
}

function CaseBattleService:Init()
	Net.functions.BattleAction.OnServerInvoke = function(player, action, payload)
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return fail("Unknown action")
		end
		local ok, result = pcall(handler, player, payload)
		if not ok then
			warn(`[CaseBattleService] {action} failed for {player.Name}: {result}`)
			return fail("Something went wrong")
		end
		return result
	end
	Net.functions.BattleLobbies.OnServerInvoke = function()
		local list = {}
		for _, lobby in lobbies do
			if not lobby.started then
				table.insert(list, summary(lobby))
			end
		end
		return list
	end
	-- Leaving fires before the player's data is saved and closed, so the refund still lands
	PlayerDataService.Leaving:Connect(function(player)
		local lobby = playerLobby[player]
		if lobby and not lobby.started then
			ACTIONS.leave(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		playerLobby[player] = nil
	end)
end

return CaseBattleService
