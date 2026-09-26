-- passive income: pays every player Income.perMinute(level) for each full minute they are in the game
-- (see Shared/Economy/Income). the minute counts from when their data loaded, so rejoining doesn't pay early.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Income = require(ReplicatedStorage.Shared.Economy.Income)
local PlayerDataService = require(script.Parent.PlayerDataService)

local IncomeService = {}

local CHECK_EVERY = 5

-- os.clock() when each player is next paid
local nextPay: { [Player]: number } = {}

local function pay(player: Player)
	local level = player:GetAttribute("Level")
	local amount = Income.perMinute(if type(level) == "number" then level else 1)
	PlayerDataService:AddCash(player, amount)
	PlayerDataService:AddStats(player, { passiveEarned = amount })
end

function IncomeService:Init()
	PlayerDataService.Loaded:Connect(function(player: Player)
		nextPay[player] = os.clock() + Income.INTERVAL
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextPay[player] = nil
	end)
end

function IncomeService:Start()
	while true do
		task.wait(CHECK_EVERY)
		local now = os.clock()
		for player, due in nextPay do
			if now >= due and player.Parent == Players and PlayerDataService:GetData(player) then
				nextPay[player] = due + Income.INTERVAL
				pay(player)
			end
		end
	end
end

return IncomeService
