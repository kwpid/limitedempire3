local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemEffects = require(Shared.Visuals.ItemEffects)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Types = require(Shared.Types)
local ItemModels = require(script.Parent.ItemModels)
local WearRenderer = require(script.Parent.WearRenderer)
local Perf = require(script.Parent.Perf)

local InspectStage = {}

local WEAR_SIZE = 512
local FOV = 32
local AUTO_SPIN = 0.35
local MIN_ZOOM, MAX_ZOOM = 0.55, 1.8
local HIDDEN_TRANSPARENCY = 0.995

type Slot = {
	item: Types.ItemInstance,
	model: Model?,
	extent: number,
	cleanupWear: (() -> ())?,
	ready: boolean,
	waiting: { thread },
	shown: boolean,
	yaw: number,
	pitch: number,
	zoom: number,
	idle: number,
	connection: RBXScriptConnection?,
}

type Stage = {
	gui: ScreenGui,
	tint: Frame,
	placeholder: ImageLabel,
	viewport: ViewportFrame,
	camera: Camera,
}

local stage: Stage? = nil
local slot: Slot? = nil

local function getStage(): Stage
	if stage and stage.gui.Parent then
		return stage
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LE_InspectStage"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local tint = Instance.new("Frame")
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(10, 12, 14)
	tint.BackgroundTransparency = 0.45
	tint.BorderSizePixel = 0
	tint.Visible = false
	tint.ZIndex = 1
	tint.Parent = gui

	local placeholder = Instance.new("ImageLabel")
	placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
	placeholder.Position = UDim2.fromScale(0.5, 0.45)
	placeholder.Size = UDim2.fromScale(0.45, 0.45)
	placeholder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	placeholder.BackgroundTransparency = 1
	placeholder.ScaleType = Enum.ScaleType.Fit
	placeholder.Visible = false
	placeholder.ZIndex = 2
	placeholder.Parent = gui

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.ImageTransparency = HIDDEN_TRANSPARENCY
	viewport.Ambient = Color3.fromRGB(150, 150, 160)
	viewport.LightColor = Color3.fromRGB(255, 248, 238)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	viewport.ZIndex = 3
	viewport.Parent = gui

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	stage = { gui = gui, tint = tint, placeholder = placeholder, viewport = viewport, camera = camera }
	return stage :: Stage
end

local function setControlsEnabled(enabled: boolean)
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	pcall(function()
		local controls = require(module):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function place(s: Slot)
	local st = getStage()
	local distance = s.extent * 1.9 * s.zoom
	st.camera.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.1, distance), Vector3.zero)
	if s.model then
		s.model:PivotTo(CFrame.Angles(s.pitch, 0, 0) * CFrame.Angles(0, s.yaw, 0))
	end
end

local function release(s: Slot)
	if s.connection then
		s.connection:Disconnect()
	end
	if s.cleanupWear then
		s.cleanupWear()
	end
	if s.model then
		s.model:Destroy()
	end
	WearRenderer.release(s.item.uid, WEAR_SIZE)
end

local function build(s: Slot)
	local item = s.item
	local source = ItemModels.find(item.assetId)
	if not source then
		Perf.note("item model not on client yet, asking server")
		source = Perf.time("item model fetch from server", ItemModels.get, item.assetId)
	end
	if source and slot == s then
		local cloneStarted = os.clock()
		local model = source:Clone()
		local boxCFrame, boxSize = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(boxCFrame.Position)
		s.extent = math.max(boxSize.Magnitude, 0.5)
		s.model = model
		ItemEffects.apply(model, item)
		place(s)
		model.Parent = getStage().viewport
		Perf.report("inspect clone into stage", os.clock() - cloneStarted)
	end

	s.ready = true
	for _, thread in s.waiting do
		task.spawn(thread)
	end
	table.clear(s.waiting)

	if source then
		task.spawn(ItemModels.preload, item.assetId)
	end

	local model = s.model
	if model and slot == s then
		local cleanup = WearRenderer.apply(model, item.uid, item.float, WEAR_SIZE)
		if slot == s then
			s.cleanupWear = cleanup
		else
			cleanup()
		end
	end
end

function InspectStage.prepare(item: Types.ItemInstance)
	if slot and slot.item.uid == item.uid then
		return
	end
	if slot then
		release(slot)
	end
	local s: Slot = {
		item = item,
		extent = 2,
		ready = false,
		waiting = {},
		shown = false,
		yaw = math.rad(-25),
		pitch = math.rad(8),
		zoom = 1,
		idle = 0,
	}
	slot = s
	getStage().viewport.ImageTransparency = HIDDEN_TRANSPARENCY
	task.spawn(build, s)
	task.spawn(function()
		local label = Instance.new("ImageLabel")
		label.Image = ItemRegistry.thumbnail(item.assetId, 420)
		pcall(ContentProvider.PreloadAsync, ContentProvider, { label })
		label:Destroy()
	end)
end

function InspectStage.show(item: Types.ItemInstance): boolean
	InspectStage.prepare(item)
	local s = slot :: Slot
	s.shown = true

	local st = getStage()
	st.tint.Visible = true
	st.placeholder.Image = ItemRegistry.thumbnail(item.assetId, 420)
	st.placeholder.ImageTransparency = 0
	st.placeholder.Visible = true
	setControlsEnabled(false)

	s.connection = RunService.RenderStepped:Connect(function(dt)
		s.idle += dt
		if s.idle > 1.5 then
			s.yaw += dt * AUTO_SPIN
		end
		place(s)
	end)

	local started = os.clock()
	if not s.ready then
		table.insert(s.waiting, coroutine.running())
		coroutine.yield()
	end
	if slot ~= s or not s.model then
		return false
	end
	Perf.report("inspect model ready", os.clock() - started)

	st.viewport.ImageTransparency = 0
	st.placeholder.ImageTransparency = 1
	return true
end

function InspectStage.rotate(dx: number, dy: number)
	local s = slot
	if not s or not s.shown then
		return
	end
	s.idle = 0
	s.yaw += dx * 0.01
	s.pitch = math.clamp(s.pitch + dy * 0.01, -1.2, 1.2)
end

function InspectStage.zoom(delta: number)
	local s = slot
	if not s or not s.shown then
		return
	end
	s.idle = 0
	s.zoom = math.clamp(s.zoom * (1 - delta * 0.1), MIN_ZOOM, MAX_ZOOM)
end

function InspectStage.hide()
	local s = slot
	if not s or not s.shown then
		return
	end
	slot = nil
	release(s)
	local st = getStage()
	st.tint.Visible = false
	st.placeholder.Visible = false
	st.viewport.ImageTransparency = HIDDEN_TRANSPARENCY
	setControlsEnabled(true)
end

return InspectStage
