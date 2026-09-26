-- the screen space our ui actually gets, kept live (rotation, resizing, notches). measured with two empty probe
-- ScreenGuis instead of the camera, because the camera includes Roblox's topbar and the device's unsafe edges.
-- api: Screen.start() (yields a few frames until the screen is measured), Screen.get() -> { safe, full, topInset, compact }, Screen.changed (signal: state)
--   safe: size of the main ui area (below Roblox's topbar, inside the device safe area)
--   full: size of the full screen inside the device safe area (the focus layer: unboxing, inspect)
--   topInset: how far Roblox's topbar reaches down into full, in pixels
--   compact: a phone sized screen, where windows take the whole screen
--   uiScale: the "Menu size" setting, a multiplier for windows and the hud

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)
local ClientSettings = require(script.Parent.ClientSettings)

export type State = { safe: Vector2, full: Vector2, topInset: number, compact: boolean, uiScale: number }

local COMPACT_HEIGHT = 620
local COMPACT_WIDTH = 900

local Screen = {
	changed = Signal.new(),
}

local state: State =
	{ safe = Vector2.new(1280, 662), full = Vector2.new(1280, 720), topInset = 58, compact = false, uiScale = 1 }

function Screen.get(): State
	return state
end

-- bottom of Roblox's topbar on screen. TopbarInset is the current api, GetGuiInset the older fallback
local function topbarBottom(): number
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and typeof(inset) == "Rect" and inset.Max.Y > 0 then
		return inset.Max.Y
	end
	local topLeft = GuiService:GetGuiInset()
	return topLeft.Y
end

function Screen.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function probe(name: string, insets: Enum.ScreenInsets): ScreenGui
		local gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.ScreenInsets = insets
		gui.Parent = playerGui
		return gui
	end
	local safe = probe("LE_ScreenSafe", Enum.ScreenInsets.CoreUISafeInsets)
	local full = probe("LE_ScreenFull", Enum.ScreenInsets.DeviceSafeInsets)

	local function update()
		local safeSize, fullSize = safe.AbsoluteSize, full.AbsoluteSize
		if safeSize.X <= 0 or fullSize.X <= 0 then
			return
		end
		local topInset = topbarBottom()
		local compact = safeSize.Y < COMPACT_HEIGHT or safeSize.X < COMPACT_WIDTH
		local uiScale = ClientSettings.get("uiScale")
		uiScale = if type(uiScale) == "number" then uiScale else 1
		if
			safeSize == state.safe
			and fullSize == state.full
			and topInset == state.topInset
			and compact == state.compact
			and uiScale == state.uiScale
		then
			return
		end
		state = { safe = safeSize, full = fullSize, topInset = topInset, compact = compact, uiScale = uiScale }
		Screen.changed:Fire(state)
	end
	-- the probes get their size within a frame or two. waiting here means the first render already knows the screen
	for _ = 1, 60 do
		if safe.AbsoluteSize.X > 0 and full.AbsoluteSize.X > 0 then
			break
		end
		task.wait()
	end
	safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	full:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update)
	end)
	ClientSettings.changed:Connect(update)
	update()
end

return Screen
