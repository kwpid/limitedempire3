-- applies the "itemEffects" graphics setting: hides the trait particles and lights on worn items in the world
-- (the ones ItemEffects marks with the LE_ItemEffect attribute) for this player only. the inspect preview room
-- (LE_InspectRoom) keeps its effects.
-- api: EffectsToggle.start()

local ClientSettings = require(script.Parent.ClientSettings)

local EFFECT_ATTRIBUTE = "LE_ItemEffect"

local EffectsToggle = {}

local function apply(instance: Instance, enabled: boolean)
	if instance:FindFirstAncestor("LE_InspectRoom") then
		return
	end
	if instance:GetAttribute(EFFECT_ATTRIBUTE) and (instance:IsA("ParticleEmitter") or instance:IsA("Light")) then
		(instance :: any).Enabled = enabled
	end
end

function EffectsToggle.start()
	local enabled = ClientSettings.get("itemEffects") ~= false
	workspace.DescendantAdded:Connect(function(instance)
		if not enabled then
			apply(instance, false)
		end
	end)
	ClientSettings.changed:Connect(function(all)
		local nextEnabled = all.itemEffects ~= false
		if nextEnabled == enabled then
			return
		end
		enabled = nextEnabled
		for _, instance in workspace:GetDescendants() do
			apply(instance, enabled)
		end
	end)
	if not enabled then
		for _, instance in workspace:GetDescendants() do
			apply(instance, false)
		end
	end
end

return EffectsToggle
