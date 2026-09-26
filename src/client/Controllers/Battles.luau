-- case battle state on the client: the open lobbies, the lobby this player is in and the last battle they played
-- (kept until they leave the result screen). everything comes from CaseBattleService through BattleUpdate.
-- api: Battles.start(), Battles.get() -> { lobbies, lobby?, battle? }, Battles.changed (signal: state),
-- Battles.action(name, payload?) -> Result (create / join / leave / addBot / start), Battles.clearBattle()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Battles = {
	changed = Signal.new(),
}

local state = { lobbies = {}, lobby = nil, battle = nil }

local function set(key: string, value: any)
	local nextState = table.clone(state)
	nextState[key] = value
	state = nextState
	Battles.changed:Fire(state)
end

function Battles.get()
	return state
end

function Battles.clearBattle()
	set("battle", nil)
end

function Battles.action(name: string, payload: any?): Types.Result<any>
	local ok, result = pcall(Net.functions.BattleAction.InvokeServer, Net.functions.BattleAction, name, payload)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Request failed, try again" }
	end
	return result
end

function Battles.start()
	Net.events.BattleUpdate.OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "lobbies" then
			set("lobbies", payload or {})
		elseif kind == "lobby" then
			set("lobby", payload)
		elseif kind == "battle" then
			set("battle", payload)
		end
	end)
	task.spawn(function()
		local ok, list = pcall(Net.functions.BattleLobbies.InvokeServer, Net.functions.BattleLobbies)
		if ok and type(list) == "table" then
			set("lobbies", list)
		end
	end)
end

return Battles
