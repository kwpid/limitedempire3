local RunService = game:GetService("RunService")

local Perf = {}

local ENABLED = RunService:IsStudio()
local REPORT_OVER = 0.015
local HITCH_OVER = 0.1

function Perf.report(label: string, seconds: number)
	if ENABLED and seconds >= REPORT_OVER then
		print(string.format("[perf] %s took %dms", label, seconds * 1000))
	end
end

function Perf.time<T...>(label: string, fn: (T...) -> ...any, ...: T...): ...any
	if not ENABLED then
		return fn(...)
	end
	local started = os.clock()
	local results = table.pack(fn(...))
	Perf.report(label, os.clock() - started)
	return table.unpack(results, 1, results.n)
end

function Perf.note(label: string)
	if ENABLED then
		print("[perf] " .. label)
	end
end

function Perf.measureNextFrame(label: string)
	if not ENABLED then
		return
	end
	local started = os.clock()
	task.spawn(function()
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		Perf.report(label, os.clock() - started)
	end)
end

function Perf.start()
	if not ENABLED then
		return
	end
	RunService.RenderStepped:Connect(function(dt)
		if dt >= HITCH_OVER then
			print(string.format("[perf] frame hitch %dms", dt * 1000))
		end
	end)
end

return Perf
