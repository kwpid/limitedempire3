-- builds display models of items (just the accessory handle, or a head for faces) and caches them in
-- ReplicatedStorage.ItemModels, named by asset id, so clients can clone them for 3d previews.
-- tries InsertService first (fast, works for roblox made items), then falls back to building a rig
-- from a HumanoidDescription which works for any catalog item. models are built on demand (CaseService prepares
-- the rolled item right away, the reel covers the build time).
--
-- api: ItemModelService:Get(assetId) -> Model? (yields, cached), ItemModelService:Prepare(assetId) (non yielding),
-- ItemModelService.meshKey(part) -> string? (numeric mesh id of a handle, used to match worn accessories to items).
-- built models carry "MeshKey" and "AccessoryName" attributes.
-- clients ask through Net.functions.RequestItemModel:InvokeServer(assetId) -> boolean

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)

local FOLDER_NAME = "ItemModels"
local REQUEST_WINDOW = 30
local REQUEST_LIMIT = 40
local RETRY_AFTER = 60

local ItemModelService = {}

local folder: Folder
local building: { [number]: { thread } } = {}
local failed: { [number]: number } = {}
local requests: { [Player]: { count: number, resetAt: number } } = {}

local STRIP_CLASSES = { "JointInstance", "WeldConstraint", "Constraint", "LuaSourceContainer", "TouchTransmitter" }

local function strip(root: Instance)
	for _, descendant in root:GetDescendants() do
		for _, className in STRIP_CLASSES do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

local function prepPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = CFrame.new()
end

local function buildFaceHead(decal: Decal): BasePart
	local head = Instance.new("Part")
	head.Name = "Handle"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = Color3.fromRGB(245, 205, 48)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = decal:Clone()
	face.Face = Enum.NormalId.Front
	face.Parent = head
	return head
end

local function findSource(container: Instance, isFace: boolean): Instance?
	if isFace then
		return container:FindFirstChildWhichIsA("Decal", true)
	end
	local accessory = container:FindFirstChildWhichIsA("Accessory", true)
	return accessory and accessory:FindFirstChild("Handle")
end

local function loadSource(assetId: number, isFace: boolean): (Instance?, Instance?)
	local ok, loaded = pcall(InsertService.LoadAsset, InsertService, assetId)
	if ok and loaded then
		local source = findSource(loaded, isFace)
		if source then
			return source, loaded
		end
		loaded:Destroy()
	end

	local description = Instance.new("HumanoidDescription")
	if isFace then
		description.Face = assetId
		description.Head = 0
	else
		local accessoryType = ItemRegistry.accessoryType(assetId)
		if not accessoryType then
			return nil, nil
		end
		description:SetAccessories({ { AssetId = assetId, AccessoryType = accessoryType, IsLayered = false } }, true)
	end
	local rigOk, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if rigOk and rig then
		local source = findSource(rig, isFace)
		if source then
			return source, rig
		end
		rig:Destroy()
	end
	return nil, nil
end

function ItemModelService.meshKey(part: Instance?): string?
	if not part then
		return nil
	end
	local meshId = ""
	if part:IsA("MeshPart") then
		meshId = part.MeshId
	else
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		meshId = mesh and mesh.MeshId or ""
	end
	return meshId:match("(%d+)%D*$")
end

local function build(assetId: number): Model?
	local isFace = ItemRegistry.isFace(assetId)
	local source, container = loadSource(assetId, isFace)
	if not source then
		return nil
	end

	local handle: BasePart
	local accessoryName = ""
	if source:IsA("Decal") then
		handle = buildFaceHead(source)
	else
		accessoryName = source.Parent and source.Parent.Name or ""
		handle = source:Clone() :: BasePart
		handle.Name = "Handle"
	end
	if container then
		container:Destroy()
	end

	strip(handle)
	prepPart(handle)

	local model = Instance.new("Model")
	model.Name = tostring(assetId)
	model:SetAttribute("AccessoryName", accessoryName)
	model:SetAttribute("MeshKey", ItemModelService.meshKey(handle) or "")
	handle.Parent = model
	model.PrimaryPart = handle
	return model
end

function ItemModelService:Get(assetId: number): Model?
	local name = tostring(assetId)
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: Model
	end
	if (failed[assetId] and os.clock() < failed[assetId]) or not ItemRegistry.get(assetId) then
		return nil
	end

	local waiting = building[assetId]
	if waiting then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
		return folder:FindFirstChild(name) :: Model?
	end

	building[assetId] = {}
	local ok, model = pcall(build, assetId)
	if ok and model then
		model.Parent = folder
	else
		failed[assetId] = os.clock() + RETRY_AFTER
		warn(`[ItemModelService] could not build model for {assetId}: {if ok then "no source" else model}`)
	end

	local waiters = building[assetId]
	building[assetId] = nil
	for _, thread in waiters do
		task.spawn(thread)
	end
	return if ok then model else nil
end

function ItemModelService:Prepare(assetId: number)
	task.spawn(self.Get, self, assetId)
end

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local entry = requests[player]
	if not entry or now >= entry.resetAt then
		entry = { count = 0, resetAt = now + REQUEST_WINDOW }
		requests[player] = entry
	end
	entry.count += 1
	return entry.count <= REQUEST_LIMIT
end

function ItemModelService:Init()
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	Net.functions.RequestItemModel.OnServerInvoke = function(player, assetId)
		if type(assetId) ~= "number" or not ItemRegistry.get(assetId) then
			return false
		end
		if folder:FindFirstChild(tostring(assetId)) then
			return true
		end
		if not allowRequest(player) then
			return false
		end
		return ItemModelService:Get(assetId) ~= nil
	end

	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
end

return ItemModelService
