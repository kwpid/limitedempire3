local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Trades = require(script.Parent.Parent.Parent.Controllers.Trades)

-- the player's trade list, re-rendering whenever it changes
local function useTrades()
	local list, setList = React.useState(Trades.get())

	React.useLayoutEffect(function()
		setList(Trades.get())
		local connection = Trades.changed:Connect(setList)
		return function()
			connection:Disconnect()
		end
	end, {})

	return list
end

return useTrades
