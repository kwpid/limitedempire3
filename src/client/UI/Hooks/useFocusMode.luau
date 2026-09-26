local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage.Packages.React)
local Perf = require(script.Parent.Parent.Parent.Controllers.Perf)

local BLUR_SIZE = 48

local CORE_TYPES = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Health,
}

local function useFocusMode(active: boolean)
	React.useLayoutEffect(function()
		if not active then
			return nil
		end
		local started = os.clock()
		local previous = {}
		for _, coreType in CORE_TYPES do
			local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
			previous[coreType] = ok and enabled
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
		end

		local blur = Instance.new("BlurEffect")
		blur.Name = "LE_FocusBlur"
		blur.Size = BLUR_SIZE
		blur.Parent = Lighting
		Perf.report("focus mode on (core gui + blur)", os.clock() - started)
		Perf.measureNextFrame("focus mode on, next frame")

		return function()
			local restoreStarted = os.clock()
			blur:Destroy()
			for coreType, enabled in previous do
				if enabled then
					pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, true)
				end
			end
			Perf.report("focus mode off (core gui restore)", os.clock() - restoreStarted)
			Perf.measureNextFrame("focus mode off, next frame")
		end
	end, { active })
end

return useFocusMode
