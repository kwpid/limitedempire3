local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

local clock, setClock = React.createBinding(os.clock())

RunService.RenderStepped:Connect(function()
	setClock(os.clock())
end)

return clock
