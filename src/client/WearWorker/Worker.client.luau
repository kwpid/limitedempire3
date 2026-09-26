local actor = script:GetActor()
if not actor then
	return
end

local WearPainter = require(actor.Parent:WaitForChild("Controllers"):WaitForChild("WearPainter"))
local done = actor:WaitForChild("Done") :: BindableEvent

local queue = {}
local busy = false

local function yieldFrame()
	task.wait()
	task.desynchronize()
end

local function drain()
	busy = true
	while #queue > 0 do
		local job = table.remove(queue, 1)
		task.desynchronize()
		local ok, buf = pcall(WearPainter.paint, job.seed, job.float, job.size, yieldFrame)
		local pixels = if ok then buffer.tostring(buf) else nil
		task.synchronize()
		done:Fire(job.jobId, pixels)
	end
	busy = false
end

actor:BindToMessage("Paint", function(jobId: number, seed: number, float: number, size: number)
	table.insert(queue, { jobId = jobId, seed = seed, float = float, size = size })
	if not busy then
		task.spawn(drain)
	end
end)

actor:SetAttribute("Ready", true)
