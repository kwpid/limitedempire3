-- stat tracker counting and replication. every case a player opens adds one to each equipped item that has a
-- stat tracker. the equipped trackers are mirrored to the "StatTrackers" player attribute (json list of
-- { a = assetId as a string, n = count } in equip order) so every client can show them on the overhead.
-- api: StatTrackerService:CountOpen(player)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local ATTRIBUTE = "StatTrackers"

local StatTrackerService = {}

local function publish(player: Player)
	local state = PlayerDataService:Get(player)
	if not state or not player.Parent then
		return
	end
	local list = {}
	for _, uid in state.equipped do
		local item = state.inventory[uid]
		if item and item.tracker then
			table.insert(list, { a = tostring(item.assetId), n = item.tracker.opens })
		end
	end
	player:SetAttribute(ATTRIBUTE, if #list > 0 then HttpService:JSONEncode(list) else nil)
end

function StatTrackerService:CountOpen(player: Player)
	local state = PlayerDataService:Get(player)
	if not state then
		return
	end
	local changed = PlayerDataService:UpdateItems(player, state.equipped, function(item)
		if not item.tracker then
			return false
		end
		item.tracker.opens += 1
		return true
	end)
	if #changed > 0 then
		publish(player)
	end
end

function StatTrackerService:Init()
	PlayerDataService.Loaded:Connect(publish)
	PlayerDataService.EquippedChanged:Connect(publish)
	PlayerDataService.InventoryChanged:Connect(publish)
	-- services start in no fixed order, so Loaded can fire before this Init connects. publishing again when the
	-- character spawns (and once in Start) makes sure a rejoining player's trackers always show
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function StatTrackerService:Start()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

return StatTrackerService
