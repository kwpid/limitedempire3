-- the 3d item preview used by the inspect view and the unbox reveal. the item is shown in the real world, in a
-- small dark room far away from the map that only this player can see, with their camera pointed at it. a
-- ViewportFrame would be simpler, but Roblox does not render particles, lights, fire, sparkles, beams or trails in
-- viewports, so trait effects and an item's own effects would be missing. the camera is given back on hide.
-- api: InspectStage.prepare(item) (starts loading early, e.g. during the case spin), InspectStage.show(item) ->
-- boolean (yields until the model is ready, false if it could not load), .rotate(dx, dy), .zoom(delta), .hide()

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
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
local ROOM_ORIGIN = Vector3.new(6000, 9000, 6000)
local ROOM_SIZE = 300
local ROOM_COLOR = Color3.fromRGB(16, 18, 22)
local FOCUS_BLUR_NAME = "LE_FocusBlur"

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
	placeholder: ImageLabel,
	room: Model,
}

type SavedCamera = {
	cameraType: Enum.CameraType,
	fieldOfView: number,
	cframe: CFrame,
}

local stage: Stage? = nil
local slot: Slot? = nil
local savedCamera: SavedCamera? = nil

-- six thin walls around ROOM_ORIGIN (looked at from inside) plus lights for the item
local function buildRoom(): Model
	local room = Instance.new("Model")
	room.Name = "LE_InspectRoom"
	local half = ROOM_SIZE / 2
	for index, normal in { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis } do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. index
		wall.Anchored = true
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Material = Enum.Material.SmoothPlastic
		wall.Color = ROOM_COLOR
		local size = Vector3.new(ROOM_SIZE, ROOM_SIZE, ROOM_SIZE)
		size -= Vector3.new(math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)) * (ROOM_SIZE - 1)
		wall.Size = size
		wall.Position = ROOM_ORIGIN + normal * half
		wall.Parent = room
	end

	local lightPart = Instance.new("Part")
	lightPart.Name = "Lights"
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.one
	lightPart.Position = ROOM_ORIGIN + Vector3.new(-8, 10, 12)
	lightPart.Parent = room
	local key = Instance.new("PointLight")
	key.Color = Color3.fromRGB(255, 246, 232)
	key.Brightness = 2.2
	key.Range = 40
	key.Shadows = false
	key.Parent = lightPart

	local fillPart = lightPart:Clone()
	fillPart.Name = "Fill"
	fillPart.Position = ROOM_ORIGIN + Vector3.new(10, 2, 8)
	local fill = fillPart:FindFirstChildOfClass("PointLight") :: PointLight
	fill.Color = Color3.fromRGB(200, 215, 255)
	fill.Brightness = 1.1
	fillPart.Parent = room

	room.Parent = workspace
	return room
end

local function getStage(): Stage
	if stage and stage.gui.Parent and stage.room.Parent then
		return stage
	end
	if stage then
		stage.gui:Destroy()
		stage.room:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LE_InspectStage"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- the item thumbnail over a dark backdrop while the 3d model loads
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

	stage = { gui = gui, placeholder = placeholder, room = buildRoom() }
	return stage :: Stage
end

local function takeCamera()
	local camera = workspace.CurrentCamera
	if not savedCamera then
		savedCamera = {
			cameraType = camera.CameraType,
			fieldOfView = camera.FieldOfView,
			cframe = camera.CFrame,
		}
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
end

local function giveCameraBack()
	local saved = savedCamera
	if not saved then
		return
	end
	savedCamera = nil
	local camera = workspace.CurrentCamera
	camera.FieldOfView = saved.fieldOfView
	camera.CFrame = saved.cframe
	camera.CameraType = saved.cameraType
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
	if s.model then
		s.model:PivotTo(CFrame.new(ROOM_ORIGIN) * CFrame.Angles(s.pitch, 0, 0) * CFrame.Angles(0, s.yaw, 0))
	end
	if s.shown then
		local distance = s.extent * 1.9 * s.zoom
		workspace.CurrentCamera.CFrame =
			CFrame.lookAt(ROOM_ORIGIN + Vector3.new(0, distance * 0.1, distance), ROOM_ORIGIN)
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
		model.Parent = getStage().room
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
	getStage()
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
	st.placeholder.Image = ItemRegistry.thumbnail(item.assetId, 420)
	st.placeholder.ImageTransparency = 0
	st.placeholder.Visible = true
	setControlsEnabled(false)
	takeCamera()

	s.connection = RunService.RenderStepped:Connect(function(dt)
		-- the menu blur would blur the item too, the dark room is the backdrop instead
		local blur = Lighting:FindFirstChild(FOCUS_BLUR_NAME)
		if blur and blur:IsA("BlurEffect") and blur.Enabled then
			blur.Enabled = false
		end
		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
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
	st.placeholder.Visible = false
	giveCameraBack()
	setControlsEnabled(true)
	local blur = Lighting:FindFirstChild(FOCUS_BLUR_NAME)
	if blur and blur:IsA("BlurEffect") then
		blur.Enabled = true
	end
end

return InspectStage
