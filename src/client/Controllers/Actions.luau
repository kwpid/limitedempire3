local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local PlayerState = require(script.Parent.PlayerState)

local Actions = {}

local function invoke(remote: RemoteFunction, ...): Types.Result<any>
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Request failed, try again" }
	end
	return result
end

function Actions.openCase(caseId: string): Types.Result<Types.ItemInstance>
	return invoke(Net.functions.OpenCase, caseId)
end

function Actions.sell(uids: { string }): Types.Result<number>
	return invoke(Net.functions.SellItems, uids)
end

function Actions.setEquipped(uids: { string }): Types.Result<nil>
	return invoke(Net.functions.SetEquipped, uids)
end

function Actions.setPinned(uid: string, pinned: boolean): Types.Result<nil>
	return invoke(Net.functions.SetPinned, uid, pinned)
end

function Actions.upgrade(uids: { string }, targetAssetId: number): Types.Result<any>
	return invoke(Net.functions.Upgrade, uids, targetAssetId)
end

function Actions.tradeUp(uids: { string }): Types.Result<Types.ItemInstance>
	return invoke(Net.functions.TradeUp, uids)
end

function Actions.hiloStart(): Types.Result<any>
	return invoke(Net.functions.HiLoStart)
end

function Actions.hiloGuess(choice: string): Types.Result<any>
	return invoke(Net.functions.HiLoGuess, choice)
end

function Actions.setCosmetic(kind: string, id: string): Types.Result<nil>
	return invoke(Net.functions.SetCosmetic, kind, id)
end

function Actions.admin(action: string, payload: any): Types.Result<any>
	return invoke(Net.functions.AdminAction, action, payload)
end

function Actions.toggleEquipped(uid: string): Types.Result<nil>
	local state = PlayerState.get()
	local equipped = table.clone(state.equipped)
	local index = table.find(equipped, uid)
	if index then
		table.remove(equipped, index)
	else
		-- only one tool can be held, equipping another tool swaps it out
		local item = state.inventory[uid]
		if item and ItemRegistry.isTool(item.assetId) then
			for i = #equipped, 1, -1 do
				local other = state.inventory[equipped[i]]
				if other and ItemRegistry.isTool(other.assetId) then
					table.remove(equipped, i)
				end
			end
		end
		table.insert(equipped, uid)
	end
	return Actions.setEquipped(equipped)
end

return Actions
