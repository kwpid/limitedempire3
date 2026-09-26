local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerState = require(script.Parent.Parent.Parent.Controllers.PlayerState)

local function usePlayerState()
	local state, setState = React.useState(PlayerState.get())

	React.useLayoutEffect(function()
		setState(PlayerState.get())
		local connection = PlayerState.changed:Connect(setState)
		return function()
			connection:Disconnect()
		end
	end, {})

	return state
end

return usePlayerState
