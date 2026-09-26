-- animated shimmer for tiers that define a gradient (divine). renders nothing for other tiers.
-- put it as a child of a bar, pill or label that is colored with tier.color. props: tier

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local clock = require(script.Parent.Parent.Clock)

local e = React.createElement

local SPEED = 0.4

local function TierGradient(props)
	local tier = props.tier
	if not (tier and tier.gradient) then
		return nil
	end
	return e("UIGradient", {
		Color = tier.gradient,
		Offset = clock:map(function(t)
			return Vector2.new(((t * SPEED) % 2) - 1, 0)
		end),
	})
end

return TierGradient
