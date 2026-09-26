-- the 3d item preview used by the inspect view and the unbox reveal. the item is a real (local only) model floating
-- in front of the player's camera, where it was when inspect opened. a ViewportFrame would be simpler, but Roblox
-- does not render particles, lights, fire, sparkles, beams or trails in viewports, so trait effects and an item's
-- own effects would be missing. a normal blur would blur the item too, so a depth of field effect keeps the item
-- sharp and blurs the world behind it heavily, with a faint dark backdrop behind the item. the player's own
-- character is hidden while inspecting and the camera is given back on hide. zooming changes the field of view
-- instead of the distance, so the item stays in focus and the background stays blurred at any zoom. while it is
-- showing, the local player gets the "LE_Inspecting" attribute (overheads hide themselves).
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
-- where the model waits (out of sight) while it loads during the case spin
local PARK_POSITION = Vector3.new(6000, 9000, 6000)
local CAMERA_DISTANCE = 2.6
local FOCUS_BLUR_NAME = "LE_FocusBlur"
local DROP_TIME = 0.55
local DROP_HEIGHT = 1.3

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
	dropStart: number?,
}

type Stage = {
	gui: ScreenGui,
	placeholder: ImageLabel,
	room: Model,
	light: BasePart,
	backdrop: BasePart,
}

type SavedCamera = {
	cameraType: Enum.CameraType,
	fieldOfView: number,
	cframe: CFrame,
}

local stage: Stage? = nil
local slot: Slot? = nil
local savedCamera: SavedCamera? = nil

local view: CFrame? = nil
local focus: DepthOfFieldEffect? = nil

local function stagePart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = PARK_POSITION
	return part
end

-- a local only model holding the item, a light for it and the dim backdrop behind it
local function buildRoom(): (Model, BasePart, BasePart)
	local room = Instance.new("Model")
	room.Name = "LE_InspectRoom"

	local light = stagePart("Light")
	light.Transparency = 1
	light.Size = Vector3.one
	local key = Instance.new("PointLight")
	key.Color = Color3.fromRGB(255, 246, 232)
	key.Brightness = 1.6
	key.Range = 24
	key.Shadows = false
	key.Parent = light
	light.Parent = room

	local backdrop = stagePart("Backdrop")
	backdrop.Size = Vector3.new(4000, 4000, 0.2)
	backdrop.Color = Color3.fromRGB(8, 9, 12)
	backdrop.Material = Enum.Material.SmoothPlastic
	backdrop.Transparency = 1
	backdrop.Parent = room

	room.Parent = workspace
	return room, light, backdrop
end

local function setCharacterHidden(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
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

	local room, light, backdrop = buildRoom()
	stage = { gui = gui, placeholder = placeholder, room = room, light = light, backdrop = backdrop }
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
	-- keep where the player was looking, levelled out
	local cframe = savedCamera and savedCamera.cframe or camera.CFrame
	local flat = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	view = CFrame.lookAt(cframe.Position, cframe.Position + flat.Unit)

	if not focus then
		focus = Instance.new("DepthOfFieldEffect")
		focus.Name = "LE_InspectFocus"
		focus.NearIntensity = 0
		focus.FarIntensity = 1
		focus.Parent = Lighting
	end
	getStage().backdrop.Transparency = 0.45
end

local function giveCameraBack()
	local saved = savedCamera
	if not saved then
		return
	end
	savedCamera = nil
	view = nil
	if focus then
		focus:Destroy()
		focus = nil
	end
	local st = getStage()
	st.backdrop.Transparency = 1
	st.backdrop.Position = PARK_POSITION
	st.light.Position = PARK_POSITION
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

-- the item drops in from above when it is first shown, with a small bounce at the end
local function dropOffset(s: Slot): number
	if not s.dropStart then
		return 0
	end
	local t = math.clamp((os.clock() - s.dropStart) / DROP_TIME, 0, 1)
	if t >= 1 then
		s.dropStart = nil
		return 0
	end
	local fall = (1 - t) ^ 3
	local bounce = math.sin(t * math.pi) * 0.08 * (1 - t)
	return s.extent * (DROP_HEIGHT * fall - bounce)
end

local function place(s: Slot)
	local model = s.model
	local camera = view
	if not s.shown or not camera then
		if model then
			model:PivotTo(CFrame.new(PARK_POSITION))
		end
		return
	end
	local distance = s.extent * CAMERA_DISTANCE
	local center = camera.Position + camera.LookVector * distance
	if model then
		local offset = dropOffset(s)
		model:PivotTo(
			CFrame.new(center + Vector3.new(0, offset, 0))
				* camera.Rotation
				* CFrame.Angles(s.pitch, 0, 0)
				* CFrame.Angles(0, s.yaw + offset * 0.4, 0)
		)
	end
	workspace.CurrentCamera.CFrame = camera
	workspace.CurrentCamera.FieldOfView = math.clamp(FOV * s.zoom, 12, 70)
	if focus then
		focus.FocusDistance = distance
		focus.InFocusRadius = math.max(s.extent * 0.7, 1)
	end
	local st = getStage()
	st.light.Position = camera.Position + camera.UpVector * s.extent + camera.RightVector * -s.extent
	-- close behind the item so as little of the world as possible sits between the item and the backdrop
	st.backdrop.CFrame =
		CFrame.lookAt(camera.Position + camera.LookVector * (distance + s.extent * 1.2), camera.Position)
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
	Players.LocalPlayer:SetAttribute("LE_Inspecting", true)

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
		setCharacterHidden(true)
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
	s.dropStart = os.clock()
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
	setCharacterHidden(false)
	Players.LocalPlayer:SetAttribute("LE_Inspecting", nil)
	setControlsEnabled(true)
	local blur = Lighting:FindFirstChild(FOCUS_BLUR_NAME)
	if blur and blur:IsA("BlurEffect") then
		blur.Enabled = true
	end
end

return InspectStage
