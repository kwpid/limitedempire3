-- selling items back for cash. equipped items that get sold are unequipped automatically by PlayerDataService.
-- api: InventoryService:Sell(player, uids) -> { ok, err?, data? = payout }
-- client calls it through Net.functions.SellItems:InvokeServer({ uid, ... }).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Valuation = require(Shared.Modifiers.Valuation)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

function InventoryService:Sell(player: Player, uids: any): Types.Result<number>
	if type(uids) ~= "table" or #uids == 0 or #uids > Config.MaxSellBatch then
		return { ok = false, err = "Invalid selection" }
	end
	local clean = {}
	local seen = {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return { ok = false, err = "Invalid selection" }
		end
		seen[uid] = true
		table.insert(clean, uid)
	end

	local removed = PlayerDataService:RemoveItems(player, clean)
	local payout = 0
	for _, item in removed do
		payout += math.floor(Valuation.value(item) * Config.SellRate)
	end
	if payout > 0 then
		PlayerDataService:AddCash(player, payout)
	end
	return { ok = true, data = payout }
end

function InventoryService:Init()
	Net.functions.SellItems.OnServerInvoke = function(player, uids)
		return InventoryService:Sell(player, uids)
	end
end

return InventoryService
