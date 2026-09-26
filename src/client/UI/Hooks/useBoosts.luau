-- the local player's active boosts (from the Boost_* attributes BoostService sets), with seconds left, ticking once
-- a second while any is active. returns { { kind, name, color, multiplier, remaining } } in Boosts.ORDER.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boosts = require(ReplicatedStorage.Shared.Economy.Boosts)

local function read()
	local player = Players.LocalPlayer
	local now = workspace:GetServerTimeNow()
	local list = {}
	for _, kind in Boosts.ORDER do
		local multiplier = player:GetAttribute(Boosts.attribute(kind))
		local endsAt = player:GetAttribute(Boosts.endsAttribute(kind))
		if type(multiplier) == "number" and type(endsAt) == "number" and endsAt > now then
			local info = Boosts.KINDS[kind]
			table.insert(list, {
				kind = kind,
				name = info.name,
				color = info.color,
				multiplier = multiplier,
				remaining = endsAt - now,
			})
		end
	end
	return list
end

local function useBoosts()
	local boosts, setBoosts = React.useState(read)

	React.useEffect(function()
		local player = Players.LocalPlayer
		local connection = player.AttributeChanged:Connect(function(name)
			if string.sub(name, 1, 6) == "Boost_" then
				setBoosts(read())
			end
		end)
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then
					setBoosts(read())
				end
			end
		end)
		return function()
			alive = false
			connection:Disconnect()
		end
	end, {})

	return boosts
end

return useBoosts
