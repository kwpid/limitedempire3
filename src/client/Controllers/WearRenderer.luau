local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Condition = require(ReplicatedStorage:WaitForChild("Shared").Modifiers.Condition)
local WearPainter = require(script.Parent.WearPainter)
local Perf = require(script.Parent.Perf)

local WearRenderer = {}

local CLEAN_FLOAT = Condition.list[1].max
local SHELL_SCALE = 1.012

local WORKER_COUNT = 3
local WORKER_READY_WAIT = 3
local JOB_TIMEOUT = 10

local cache: { [string]: EditableImage } = {}
local generating: { [string]: boolean } = {}
local cancelled: { [string]: boolean } = {}

local workers: { Actor } = {}
local nextWorker = 0
local nextJob = 0
local jobs: { [number]: thread } = {}

local function onJobDone(jobId: number, pixels: string?)
	local thread = jobs[jobId]
	if thread then
		jobs[jobId] = nil
		task.spawn(thread, if type(pixels) == "string" then buffer.fromstring(pixels) else nil)
	end
end

local function readyWorker(): Actor?
	local deadline = os.clock() + WORKER_READY_WAIT
	repeat
		for _ = 1, #workers do
			nextWorker = nextWorker % #workers + 1
			local worker = workers[nextWorker]
			if worker:GetAttribute("Ready") then
				return worker
			end
		end
		task.wait()
	until os.clock() > deadline
	return nil
end

local warned: { [string]: boolean } = {}
local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn("[WearRenderer] " .. message)
	end
end

local function paintAsync(seed: number, float: number, size: number): buffer?
	local worker = if #workers > 0 then readyWorker() else nil
	if not worker then
		warnOnce("no wear workers are ready, skipping wear")
		return nil
	end

	nextJob += 1
	local jobId = nextJob
	jobs[jobId] = coroutine.running()
	task.delay(JOB_TIMEOUT, onJobDone, jobId, nil)
	worker:SendMessage("Paint", jobId, seed, float, size)
	local buf = coroutine.yield()
	if not buf then
		warnOnce("a wear worker did not answer, skipping wear for this item")
	end
	return buf
end

function WearRenderer.start()
	local template = script.Parent.Parent:WaitForChild("WearWorker", 10)
	if not template or not template:IsA("Actor") then
		return
	end
	local function hook(actor: Actor)
		local done = actor:FindFirstChild("Done") :: BindableEvent?
		if not done then
			done = Instance.new("BindableEvent")
			done.Name = "Done"
			done.Parent = actor
		end
		done.Event:Connect(onJobDone)
		table.insert(workers, actor)
	end
	local clones = {}
	for i = 2, WORKER_COUNT do
		local clone = template:Clone()
		clone.Name = "WearWorker" .. i
		clone:SetAttribute("Ready", nil)
		table.insert(clones, clone)
	end
	hook(template)
	for _, clone in clones do
		hook(clone)
		clone.Parent = template.Parent
	end
end

function WearRenderer.isClean(float: number): boolean
	return float < CLEAN_FLOAT
end

function WearRenderer.generate(uid: string, float: number, size: number): EditableImage?
	local key = uid .. ":" .. size
	while generating[key] do
		task.wait()
	end
	if cache[key] then
		return cache[key]
	end
	if WearRenderer.isClean(float) then
		return nil
	end
	generating[key] = true
	cancelled[key] = nil

	local paintStarted = os.clock()
	local buf = paintAsync(WearPainter.seedFrom(uid), float, size)
	Perf.note(string.format("wear %d painted in background, %dms wall time", size, (os.clock() - paintStarted) * 1000))
	generating[key] = nil
	if cancelled[key] or not buf then
		cancelled[key] = nil
		return nil
	end

	local started = os.clock()
	local ok, image = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(size, size) })
	if not ok or not image then
		return nil
	end
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
	cache[key] = image
	Perf.report("wear image upload", os.clock() - started)
	return image
end

function WearRenderer.release(uid: string, size: number)
	local key = uid .. ":" .. size
	if generating[key] then
		cancelled[key] = true
	end
	local image = cache[key]
	if image then
		cache[key] = nil
		image:Destroy()
	end
end

local function makeShell(part: BasePart): BasePart?
	if part:IsA("MeshPart") then
		local shell = part:Clone()
		shell:ClearAllChildren()
		shell.TextureID = ""
		return shell
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if not mesh or mesh.MeshType ~= Enum.MeshType.FileMesh or mesh.MeshId == "" then
		return nil
	end
	local ok, shell = pcall(AssetService.CreateMeshPartAsync, AssetService, Content.fromUri(mesh.MeshId))
	if not ok or not shell then
		return nil
	end
	shell.Size = shell.Size * mesh.Scale
	shell.CFrame = part.CFrame * CFrame.new(mesh.Offset)
	return shell
end

function WearRenderer.tintDecals(root: Instance, float: number): () -> ()
	local restore = {}
	local grime = Color3.fromRGB(120, 105, 90)
	local targets = root:GetDescendants()
	for _, decal in targets do
		if decal:IsA("Decal") then
			restore[decal] = decal.Color3
			decal.Color3 = Color3.new(1, 1, 1):Lerp(grime, float * 0.6)
		end
	end
	return function()
		for decal, color in restore do
			if decal.Parent then
				decal.Color3 = color
			end
		end
	end
end

function WearRenderer.apply(root: Instance, uid: string, float: number, size: number): () -> ()
	local shells = {}
	local restoreDecals = WearRenderer.tintDecals(root, float)

	local image = WearRenderer.generate(uid, float, size)
	if image then
		local candidates = root:GetDescendants()
		if root:IsA("BasePart") then
			table.insert(candidates, 1, root)
		end
		for _, part in candidates do
			if not part:IsA("BasePart") or part.Name == "WearShell" then
				continue
			end
			local shell = Perf.time("wear shell mesh", makeShell, part)
			if not shell then
				continue
			end
			if not part:IsDescendantOf(game) then
				shell:Destroy()
				continue
			end
			local okAppearance, appearance = Perf.time("wear surface appearance", pcall, AssetService.CreateSurfaceAppearanceAsync, AssetService, {
				ColorMap = Content.fromObject(image),
			})
			if not okAppearance or not appearance then
				shell:Destroy()
				continue
			end
			appearance.AlphaMode = Enum.AlphaMode.Transparency

			local cframe = shell.CFrame
			shell.Name = "WearShell"
			shell.Size *= SHELL_SCALE
			shell.CFrame = cframe
			shell.Transparency = 0.02
			shell.Anchored = part.Anchored
			shell.CanCollide = false
			shell.CanQuery = false
			shell.CanTouch = false
			shell.Massless = true
			shell.CastShadow = false
			appearance.Parent = shell

			if not part.Anchored then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = shell
				weld.Parent = shell
			end
			shell.Parent = part
			table.insert(shells, shell)
		end
	end

	return function()
		for _, shell in shells do
			shell:Destroy()
		end
		restoreDecals()
	end
end

return WearRenderer
