-- the current value of one of the local player's settings, re-renders when it changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ClientSettings = require(script.Parent.Parent.Parent.Controllers.ClientSettings)

local function useSetting(id: string): any
	local value, setValue = React.useState(ClientSettings.get(id))

	React.useLayoutEffect(function()
		setValue(ClientSettings.get(id))
		local connection = ClientSettings.changed:Connect(function(all)
			setValue(all[id])
		end)
		return function()
			connection:Disconnect()
		end
	end, { id })

	return value
end

return useSetting
