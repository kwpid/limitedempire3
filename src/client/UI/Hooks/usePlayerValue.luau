local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local STAT_NAME = "Value"

local function usePlayerValue(player: Player): number
	local value, setValue = React.useState(0)

	React.useLayoutEffect(function()
		local connections = {}
		local statConnection: RBXScriptConnection? = nil

		local function bindStat(stat: Instance)
			if not stat:IsA("ValueBase") or stat.Name ~= STAT_NAME then
				return
			end
			if statConnection then
				statConnection:Disconnect()
			end
			setValue((stat :: any).Value)
			statConnection = (stat :: any).Changed:Connect(function(newValue)
				setValue(newValue)
			end)
		end

		local function bindFolder(folder: Instance)
			if folder.Name ~= "leaderstats" then
				return
			end
			local stat = folder:FindFirstChild(STAT_NAME)
			if stat then
				bindStat(stat)
			end
			table.insert(connections, folder.ChildAdded:Connect(bindStat))
		end

		local folder = player:FindFirstChild("leaderstats")
		if folder then
			bindFolder(folder)
		end
		table.insert(connections, player.ChildAdded:Connect(bindFolder))

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
			if statConnection then
				statConnection:Disconnect()
			end
		end
	end, { player })

	return value
end

return usePlayerValue
