-- single place that defines every remote. the server creates them on first require, the client waits for them.
-- api: Net.events.<Name> (RemoteEvent), Net.functions.<Name> (RemoteFunction)
-- to add a remote, add its name to EVENTS or FUNCTIONS below and use it from both sides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"StateDelta",
	"Announce",
	"BattleUpdate",
	"ProgressEvent",
	"TradeUpdate",
}

local FUNCTIONS = {
	"GetState",
	"OpenCase",
	"SellItems",
	"SetEquipped",
	"AdminAction",
	"RequestItemModel",
	"SetSetting",
	"SetCosmetic",
	"SetPinned",
	"Upgrade",
	"TradeUp",
	"HiLoStart",
	"HiLoGuess",
	"BattleAction",
	"BattleLobbies",
	"GetLeaderboard",
	"TradeAction",
	"CashGame",
	"RedeemCode",
	"DailyLogin",
}

local FOLDER_NAME = "Remotes"
local isServer = RunService:IsServer()

local folder: Folder
if isServer then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function resolve(name: string, className: string): Instance
	if isServer then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

local events: { [string]: RemoteEvent } = {}
for _, name in EVENTS do
	events[name] = resolve(name, "RemoteEvent") :: RemoteEvent
end

local functions: { [string]: RemoteFunction } = {}
for _, name in FUNCTIONS do
	functions[name] = resolve(name, "RemoteFunction") :: RemoteFunction
end

return {
	events = events,
	functions = functions,
}
