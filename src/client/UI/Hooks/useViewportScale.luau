local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local function compute(baseSize: Vector2): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X / baseSize.X, viewport.Y / baseSize.Y), 0.45, 1)
end

local function useViewportScale(baseSize: Vector2): number
	local scale, setScale = React.useState(compute(baseSize))

	React.useLayoutEffect(function()
		local cameraConnection, viewportConnection
		local function bind()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
			local camera = workspace.CurrentCamera
			if camera then
				viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setScale(compute(baseSize))
				end)
			end
			setScale(compute(baseSize))
		end
		bind()
		cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
		return function()
			cameraConnection:Disconnect()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
		end
	end, {})

	return scale
end

return useViewportScale
