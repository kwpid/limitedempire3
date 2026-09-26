-- trait visuals (particles, light, mesh tint) and a light condition tint for an item's handle.
-- shared so the server can dress worn accessories and the client can dress 3d previews the same way.
-- api: ItemEffects.apply(container, item) where container is an Accessory or Model with a "Handle" part.
-- safe to call more than once, old effects are replaced. texture wear is separate (client WearRenderer).

local Shared = script.Parent.Parent
local Condition = require(Shared.Modifiers.Condition)
local Traits = require(Shared.Modifiers.Traits)
local Types = require(Shared.Types)

local EFFECT_ATTRIBUTE = "LE_ItemEffect"
local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local ItemEffects = {}

local function clear(handle: Instance)
	for _, child in handle:GetChildren() do
		if child:GetAttribute(EFFECT_ATTRIBUTE) then
			child:Destroy()
		end
	end
end

local function mark(instance: any): any
	instance:SetAttribute(EFFECT_ATTRIBUTE, true)
	return instance
end

function ItemEffects.apply(container: Instance, item: Types.ItemInstance)
	local handle = container:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	clear(handle)

	local band = Condition.fromFloat(item.float)
	local traitIds = Traits.of(item)
	local trait = Traits.get(traitIds[1])
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
		mesh.VertexColor = if trait and trait.meshTint
			then trait.meshTint
			else Vector3.new(band.tint.R, band.tint.G, band.tint.B)
	end

	if not trait then
		return
	end

	-- one emitter per trait, stacked traits emit a bit less so the best trait stays the main look
	for index, id in traitIds do
		local stacked = Traits.get(id)
		if not stacked then
			continue
		end
		local particles = mark(Instance.new("ParticleEmitter"))
		particles.Texture = PARTICLE_TEXTURE
		particles.Color = stacked.color
		particles.Rate = if index == 1 then stacked.particleRate else stacked.particleRate * 0.6
		particles.Lifetime = NumberRange.new(0.6, 1.2)
		particles.Speed = NumberRange.new(0.4, 1.4)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.LightEmission = 1
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Parent = handle
	end

	if trait.light then
		local light = mark(Instance.new("PointLight"))
		light.Color = trait.color.Keypoints[1].Value
		light.Brightness = 1.5
		light.Range = 6
		light.Parent = handle
	end
end

return ItemEffects
