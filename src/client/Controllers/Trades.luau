-- the player's trades on the client, kept in step by TradeService through TradeUpdate (the full list on every
-- change, with an optional toast). api: Trades.start(), Trades.get() -> { Trade }, Trades.changed (signal: list),
-- Trades.action(name, payload?) -> Result (see TradeService for the actions), Trades.inboundCount() -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local Notifications = require(script.Parent.Notifications)
local Sfx = require(script.Parent.Sfx)

local NOTE_COLORS = {
	info = Color3.fromRGB(120, 190, 255),
	good = Color3.fromRGB(130, 210, 120),
	bad = Color3.fromRGB(220, 110, 90),
}

local Trades = {
	changed = Signal.new(),
}

local list: { Types.Trade } = {}

local function set(nextList: { Types.Trade })
	list = nextList
	Trades.changed:Fire(list)
end

function Trades.get(): { Types.Trade }
	return list
end

function Trades.inboundCount(): number
	local count = 0
	for _, trade in list do
		if trade.direction == "inbound" and trade.status == "pending" then
			count += 1
		end
	end
	return count
end

function Trades.action(name: string, payload: any?): Types.Result<any>
	local ok, result = pcall(Net.functions.TradeAction.InvokeServer, Net.functions.TradeAction, name, payload)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Request failed, try again" }
	end
	return result
end

function Trades.start()
	Net.events.TradeUpdate.OnClientEvent:Connect(function(nextList, note)
		if type(nextList) == "table" then
			set(nextList)
		end
		if type(note) == "table" and type(note.text) == "string" then
			Sfx.play(if note.kind == "bad" then "error" elseif note.kind == "good" then "unlock" else "tab")
			Notifications.push(note.text, NOTE_COLORS[note.kind] or NOTE_COLORS.info)
		end
	end)

	task.spawn(function()
		for _ = 1, 10 do
			local result = Trades.action("list")
			if result.ok then
				set(result.data)
				return
			end
			task.wait(2)
		end
	end)
end

return Trades
