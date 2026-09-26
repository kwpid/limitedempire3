local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local function usePlayerAttribute(name: string, target: Player?): any
	local player = target or Players.LocalPlayer
	local value, setValue = React.useState(player:GetAttribute(name))

	React.useLayoutEffect(function()
		setValue(player:GetAttribute(name))
		local connection = player:GetAttributeChangedSignal(name):Connect(function()
			setValue(player:GetAttribute(name))
		end)
		return function()
			connection:Disconnect()
		end
	end, { name, player })

	return value
end

return usePlayerAttribute
