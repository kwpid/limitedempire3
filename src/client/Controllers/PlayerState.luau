local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local PlayerState = {
	changed = Signal.new(),
}

local state: Types.PlayerState = {
	cash = 0,
	inventory = {},
	equipped = {},
	version = 0,
}
local loaded = false
local pending = {}

local function applyDelta(kind: string, payload: any)
	local nextState = table.clone(state)
	if kind == "cash" then
		nextState.cash = payload
	elseif kind == "add" then
		nextState.inventory = table.clone(state.inventory)
		nextState.inventory[payload.uid] = payload
	elseif kind == "update" then
		nextState.inventory = table.clone(state.inventory)
		for _, item in payload do
			nextState.inventory[item.uid] = item
		end
	elseif kind == "remove" then
		nextState.inventory = table.clone(state.inventory)
		for _, uid in payload do
			nextState.inventory[uid] = nil
		end
	elseif kind == "equipped" then
		nextState.equipped = payload
	elseif kind == "replace" then
		nextState.cash = payload.cash
		nextState.inventory = payload.inventory
		nextState.equipped = payload.equipped
	end
	state = nextState
end

function PlayerState.get(): Types.PlayerState
	return state
end

function PlayerState.isLoaded(): boolean
	return loaded
end

function PlayerState.start()
	Net.events.StateDelta.OnClientEvent:Connect(function(version: number, kind: string, payload: any)
		if not loaded then
			table.insert(pending, { version = version, kind = kind, payload = payload })
			return
		end
		if version <= state.version then
			return
		end
		applyDelta(kind, payload)
		state.version = version
		PlayerState.changed:Fire(state)
	end)

	task.spawn(function()
		local snapshot
		repeat
			local ok, result = pcall(Net.functions.GetState.InvokeServer, Net.functions.GetState)
			snapshot = ok and result or nil
			if not snapshot then
				task.wait(1)
			end
		until snapshot

		state = snapshot
		loaded = true
		table.sort(pending, function(a, b)
			return a.version < b.version
		end)
		for _, delta in pending do
			if delta.version > state.version then
				applyDelta(delta.kind, delta.payload)
				state.version = delta.version
			end
		end
		table.clear(pending)
		PlayerState.changed:Fire(state)
	end)
end

return PlayerState
