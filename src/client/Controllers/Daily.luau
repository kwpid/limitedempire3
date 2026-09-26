-- the daily login calendar on the client (DailyService on the server). refreshes itself when the utc day rolls over.
-- api: Daily.start(), Daily.get() -> view? (DailyLogin.view + resetsIn, fetchedAt), Daily.changed (signal: view),
-- Daily.claim() -> Result (the view, with reward)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Daily = {
	changed = Signal.new(),
}

local view = nil
local rolloverThread: thread? = nil

local function invoke(action: string): Types.Result<any>
	local ok, result = pcall(Net.functions.DailyLogin.InvokeServer, Net.functions.DailyLogin, action)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Request failed, try again" }
	end
	return result
end

local refresh

local function set(nextView)
	nextView.fetchedAt = os.clock()
	view = nextView
	Daily.changed:Fire(view)
	-- look again just after the day changes, when a new claim opens up
	if rolloverThread then
		pcall(task.cancel, rolloverThread)
	end
	rolloverThread = task.delay(math.max(nextView.resetsIn, 0) + 3, refresh)
end

function refresh()
	for _ = 1, 10 do
		local result = invoke("get")
		if result.ok then
			set(result.data)
			return
		end
		task.wait(3)
	end
end

function Daily.get()
	return view
end

function Daily.claim(): Types.Result<any>
	local result = invoke("claim")
	if result.ok then
		set(result.data)
	end
	return result
end

function Daily.start()
	task.spawn(refresh)
end

return Daily
