local CollectionService = game:GetService("CollectionService")

local WearRenderer = require(script.Parent.WearRenderer)

local AvatarWear = {}

local WORN_TAG = "LE_WornItem"
local WEAR_SIZE = 256
local ATTRIBUTE_WAIT = 3

type Active = { cleanup: () -> (), uid: string }

local active: { [Instance]: Active } = {}

local function release(target: Instance)
	local entry = active[target]
	if entry then
		active[target] = nil
		entry.cleanup()
		WearRenderer.release(entry.uid, WEAR_SIZE)
	end
end

local function readAttributes(target: Instance): (string?, number?)
	local deadline = os.clock() + ATTRIBUTE_WAIT
	repeat
		local uid, float = target:GetAttribute("LE_Uid"), target:GetAttribute("LE_Float")
		if type(uid) == "string" and type(float) == "number" then
			return uid, float
		end
		task.wait()
	until os.clock() > deadline or not target.Parent
	return nil, nil
end

local function onTagged(target: Instance)
	release(target)
	local uid, float = readAttributes(target)
	if not uid or not float or WearRenderer.isClean(float) then
		return
	end
	if not CollectionService:HasTag(target, WORN_TAG) or not target:IsDescendantOf(workspace) then
		return
	end

	if target:GetAttribute("LE_DecalOnly") then
		active[target] = { cleanup = WearRenderer.tintDecals(target, float), uid = uid }
		return
	end

	local handle = if target:IsA("BasePart") then target else target:WaitForChild("Handle", 10)
	if not handle or active[target] or not CollectionService:HasTag(target, WORN_TAG) then
		return
	end
	active[target] = { cleanup = WearRenderer.apply(handle, uid, float, WEAR_SIZE), uid = uid }
end

function AvatarWear.start()
	CollectionService:GetInstanceAddedSignal(WORN_TAG):Connect(function(target)
		task.spawn(onTagged, target)
	end)
	CollectionService:GetInstanceRemovedSignal(WORN_TAG):Connect(release)
	for _, target in CollectionService:GetTagged(WORN_TAG) do
		task.spawn(onTagged, target)
	end
end

return AvatarWear
