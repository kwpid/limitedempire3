-- the local player's settings (defaults filled in) for code outside react, plus a signal when they change.
-- react components use the UI/Hooks/useSetting hook instead.
-- api: ClientSettings.get(id) -> value, ClientSettings.all() -> { [id]: value }, ClientSettings.changed (signal: all),
-- ClientSettings.set(id, value) (sends it to the server, shows an error toast if it is rejected)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Settings = require(Shared.Settings)
local Signal = require(Shared.Util.Signal)
local PlayerState = require(script.Parent.PlayerState)

local ClientSettings = {
	changed = Signal.new(),
}

local lastSaved = PlayerState.get().settings
local current = Settings.resolve(lastSaved)

PlayerState.changed:Connect(function(state)
	if state.settings == lastSaved then
		return
	end
	lastSaved = state.settings
	current = Settings.resolve(state.settings)
	ClientSettings.changed:Fire(current)
end)

function ClientSettings.get(id: string): any
	return current[id]
end

function ClientSettings.all(): { [string]: any }
	return current
end

-- applied locally right away so the window feels instant, rolled back if the server rejects it
function ClientSettings.set(id: string, value: any)
	current = table.clone(current)
	current[id] = value
	ClientSettings.changed:Fire(current)
	task.spawn(function()
		local ok, result = pcall(Net.functions.SetSetting.InvokeServer, Net.functions.SetSetting, id, value)
		if not ok or type(result) ~= "table" or not result.ok then
			current = Settings.resolve(lastSaved)
			ClientSettings.changed:Fire(current)
			local Notifications = require(script.Parent.Notifications)
			Notifications.push("Could not save that setting", Color3.fromRGB(160, 52, 52))
		end
	end)
end

return ClientSettings
