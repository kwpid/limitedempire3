local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
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

function Actions.admin(action: string, payload: any): Types.Result<any>
	return invoke(Net.functions.AdminAction, action, payload)
end

function Actions.toggleEquipped(uid: string): Types.Result<nil>
	local equipped = table.clone(PlayerState.get().equipped)
	local index = table.find(equipped, uid)
	if index then
		table.remove(equipped, index)
	else
		table.insert(equipped, uid)
	end
	return Actions.setEquipped(equipped)
end

return Actions
