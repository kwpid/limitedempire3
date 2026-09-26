local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Screen = require(script.Parent.Parent.Parent.Controllers.Screen)

-- the live screen areas (see Controllers/Screen), re-rendering when they change
local function useScreen(): Screen.State
	local state, setState = React.useState(Screen.get())

	React.useLayoutEffect(function()
		setState(Screen.get())
		local connection = Screen.changed:Connect(setState)
		return function()
			connection:Disconnect()
		end
	end, {})

	return state
end

return useScreen
