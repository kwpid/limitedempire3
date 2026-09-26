-- the daily login calendar (rules in Shared/Progress/DailyLogin), saved as data.login = { streak, lastClaimDay }.
-- client calls Net.functions.DailyLogin:InvokeServer("get" | "claim") -> { ok, err?, data = view } where view is
-- DailyLogin.view plus resetsIn (seconds until the next utc day) and, after a claim, the reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Career = require(Shared.Progress.Career)
local DailyLogin = require(Shared.Progress.DailyLogin)
local Net = require(Shared.Net)
local Seasons = require(Shared.Progress.Seasons)
local Types = require(Shared.Types)
local BoostService = require(script.Parent.BoostService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressService = require(script.Parent.ProgressService)

local DailyService = {}

local DAY = 86400

local busy: { [Player]: boolean } = {}

local function viewOf(data)
	local today = Seasons.today()
	local view = DailyLogin.view(data.login, today)
	view.resetsIn = (today + 1) * DAY - os.time()
	return view
end

function DailyService:Get(player: Player): Types.Result<any>
	local data = PlayerDataService:GetData(player)
	if not data then
		return { ok = false, err = "Your data is still loading" }
	end
	return { ok = true, data = viewOf(data) }
end

function DailyService:Claim(player: Player): Types.Result<any>
	local data = PlayerDataService:GetData(player)
	if not data then
		return { ok = false, err = "Your data is still loading" }
	end
	local today = Seasons.today()
	local before = DailyLogin.view(data.login, today)
	if not before.claimable then
		return { ok = false, err = "Already claimed today, come back tomorrow" }
	end
	-- the streak carries on from yesterday's claim, otherwise it starts over
	local streak = before.streak + 1
	data.login = { streak = streak, lastClaimDay = today }
	local day = DailyLogin.dayFor(streak)
	local reward = DailyLogin.REWARDS[day]

	local cash = math.floor(reward.cash * BoostService:Multiplier(player, "cash"))
	PlayerDataService:AddCash(player, cash)
	ProgressService:AddSp(player, reward.sp, true)
	ProgressService:Track(player, "logins", 1, Career.XP.dailyLogin)

	local view = viewOf(data)
	view.reward = { day = day, cash = cash, sp = reward.sp }
	return { ok = true, data = view }
end

function DailyService:Init()
	Net.functions.DailyLogin.OnServerInvoke = function(player, action)
		if busy[player] then
			return { ok = false, err = "Slow down a little" }
		end
		busy[player] = true
		local ok, result = pcall(function()
			if action == "claim" then
				return DailyService:Claim(player)
			end
			return DailyService:Get(player)
		end)
		busy[player] = nil
		if not ok then
			warn(`[DailyService] {tostring(action)} failed for {player.Name}: {result}`)
			return { ok = false, err = "Something went wrong, try again" }
		end
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return DailyService
