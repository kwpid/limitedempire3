-- keeps each player's leaderstats in sync. "Value" is the total value of everything in their inventory
-- (condition, trait and serial bonuses included), recalculated whenever their inventory changes.
-- the overhead ui reads the same stat, so there is one source for "how much is this player worth".
-- api: LeaderstatsService:GetValue(player) -> number

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Valuation = require(ReplicatedStorage.Shared.Modifiers.Valuation)
local PlayerDataService = require(script.Parent.PlayerDataService)

local STAT_NAME = "Value"

local LeaderstatsService = {}

local stats: { [Player]: IntValue } = {}

local function totalValue(player: Player): number
	local state = PlayerDataService:Get(player)
	if not state then
		return 0
	end
	local total = 0
	for _, item in state.inventory do
		total += Valuation.value(item)
	end
	return total
end

local function ensureStat(player: Player): IntValue
	local existing = stats[player]
	if existing and existing.Parent then
		return existing
	end
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local stat = folder:FindFirstChild(STAT_NAME) :: IntValue?
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = STAT_NAME
		stat.Parent = folder
	end
	stats[player] = stat :: IntValue
	return stat :: IntValue
end

local function refresh(player: Player)
	if player.Parent then
		ensureStat(player).Value = totalValue(player)
	end
end

function LeaderstatsService:GetValue(player: Player): number
	local stat = stats[player]
	return stat and stat.Value or 0
end

function LeaderstatsService:Init()
	PlayerDataService.Loaded:Connect(refresh)
	PlayerDataService.InventoryChanged:Connect(refresh)
	Players.PlayerRemoving:Connect(function(player)
		stats[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if PlayerDataService:Get(player) then
			task.spawn(refresh, player)
		end
	end
end

return LeaderstatsService
