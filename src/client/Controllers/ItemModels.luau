local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local ItemModels = {}

local TIMEOUT = 15
local WARM_BATCH = 4
local WARM_GAP = 0.2

type LoadState = { done: boolean, waiting: { thread } }

local loads: { [number]: LoadState } = {}

local function getFolder(): Instance?
	return ReplicatedStorage:WaitForChild("ItemModels", TIMEOUT)
end

function ItemModels.find(assetId: number): Model?
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")
	return folder and folder:FindFirstChild(tostring(assetId)) :: Model?
end

function ItemModels.get(assetId: number): Model?
	local existing = ItemModels.find(assetId)
	if existing then
		return existing
	end
	local folder = getFolder()
	if not folder then
		return nil
	end
	local ok, ready = pcall(Net.functions.RequestItemModel.InvokeServer, Net.functions.RequestItemModel, assetId)
	if not ok or not ready then
		return nil
	end
	return folder:WaitForChild(tostring(assetId), TIMEOUT) :: Model?
end

function ItemModels.isLoaded(assetId: number): boolean
	local state = loads[assetId]
	return state ~= nil and state.done
end

local function startLoad(assetId: number, models: { Model })
	local state = loads[assetId]
	if state then
		return state
	end
	state = { done = false, waiting = {} }
	loads[assetId] = state
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, models)
		state.done = true
		for _, thread in state.waiting do
			task.spawn(thread)
		end
		table.clear(state.waiting)
	end)
	return state
end

function ItemModels.preload(assetId: number): Model?
	local model = ItemModels.get(assetId)
	if not model then
		return nil
	end
	local state = startLoad(assetId, { model })
	if not state.done then
		table.insert(state.waiting, coroutine.running())
		coroutine.yield()
	end
	return model
end

local function contentIds(model: Instance): { string }
	local ids = {}
	local function add(id: string?)
		if id and id ~= "" then
			table.insert(ids, id)
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			add(descendant.MeshId)
			add(descendant.TextureID)
		elseif descendant:IsA("SpecialMesh") then
			add(descendant.MeshId)
			add(descendant.TextureId)
		elseif descendant:IsA("Decal") then
			add(descendant.Texture)
		end
	end
	return ids
end

local DONE_STATUSES = {}
for _, status in Enum.AssetFetchStatus:GetEnumItems() do
	if status.Name == "Success" or status.Name == "Failure" or status.Name == "TimedOut" then
		DONE_STATUSES[status] = true
	end
end

function ItemModels.isFetched(model: Instance): boolean
	for _, id in contentIds(model) do
		local ok, status = pcall(ContentProvider.GetAssetFetchStatus, ContentProvider, id)
		if ok and not DONE_STATUSES[status] then
			return false
		end
	end
	return true
end

function ItemModels.warmAll()
	task.spawn(function()
		local folder = getFolder()
		if not folder then
			return
		end
		local pending = {}
		local function enqueue(model: Instance)
			local assetId = tonumber(model.Name)
			if assetId and not loads[assetId] and model:IsA("Model") then
				table.insert(pending, model)
			end
		end
		folder.ChildAdded:Connect(enqueue)
		for _, model in folder:GetChildren() do
			enqueue(model)
		end
		while true do
			if #pending == 0 then
				task.wait(0.5)
			else
				local batch = {}
				for _ = 1, math.min(WARM_BATCH, #pending) do
					local model = table.remove(pending, 1)
					local assetId = tonumber(model.Name)
					if assetId and not loads[assetId] then
						loads[assetId] = { done = false, waiting = {} }
						table.insert(batch, model)
					end
				end
				if #batch > 0 then
					pcall(ContentProvider.PreloadAsync, ContentProvider, batch)
					for _, model in batch do
						local state = loads[tonumber(model.Name) :: number]
						state.done = true
						for _, thread in state.waiting do
							task.spawn(thread)
						end
						table.clear(state.waiting)
					end
				end
				task.wait(WARM_GAP)
			end
		end
	end)
end

function ItemModels.preloadExisting(assetIds: { number })
	for _, assetId in assetIds do
		local model = ItemModels.find(assetId)
		if model then
			startLoad(assetId, { model })
		end
	end
end

return ItemModels
