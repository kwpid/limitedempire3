-- how big each layer of the ui draws, from the live screen areas (Controllers/Screen). everything is laid out in
-- design units and scaled down to fit, never up (a big monitor shows it at 1x, a phone shrinks it).
--   hud (wallet, bottom nav): fits HUD_DESIGN into the main ui area
--   focus (unboxing, inspect, reveals, toasts): fits FOCUS_DESIGN into the full screen, inside the device safe area
-- the "Menu size" setting (screen.uiScale) grows or shrinks windows and the hud, but never past what fits.
--   windows: 1000 x 600 centered on bigger screens. on phones (compact) a window fills the screen instead (the hud
--   hides while one is open) and is at least 1000 x COMPACT_WINDOW_HEIGHT units, so text stays as big as possible.

local Layout = {}

Layout.HUD_DESIGN = Vector2.new(900, 480)
Layout.FOCUS_DESIGN = Vector2.new(1200, 660)
Layout.WINDOW_SIZE = Vector2.new(1000, 600)
-- room kept around a window on bigger screens, for the hud
local WINDOW_MARGIN = Vector2.new(60, 130)
local COMPACT_WINDOW_HEIGHT = 520
local COMPACT_EDGE = 8
local MIN_SCALE = 0.45

local function fit(area: Vector2, design: Vector2): number
	return math.clamp(math.min(area.X / design.X, area.Y / design.Y), MIN_SCALE, 1)
end

-- fit, times the menu size setting, but never bigger than design actually fits in area
local function fitSized(screen, area: Vector2, design: Vector2): number
	local exact = math.min(area.X / design.X, area.Y / design.Y)
	return math.clamp(fit(area, design) * (screen.uiScale or 1), MIN_SCALE, math.max(exact, MIN_SCALE))
end

function Layout.hudScale(screen): number
	return fitSized(screen, screen.safe, Layout.HUD_DESIGN)
end

function Layout.focusScale(screen): number
	return fit(screen.full, Layout.FOCUS_DESIGN)
end

-- the top of the focus layer covered by Roblox's topbar, in focus units
function Layout.focusTop(screen): number
	return screen.topInset / Layout.focusScale(screen)
end

-- { scale, size (units), offsetY (pixels, from the center) } for a window
function Layout.window(screen)
	if not screen.compact then
		return {
			scale = fitSized(screen, screen.safe, Layout.WINDOW_SIZE + WINDOW_MARGIN),
			size = Layout.WINDOW_SIZE,
			offsetY = -30,
		}
	end
	local area = screen.safe - Vector2.new(COMPACT_EDGE * 2, COMPACT_EDGE * 2)
	local scale = math.clamp(area.Y / COMPACT_WINDOW_HEIGHT * (screen.uiScale or 1), MIN_SCALE, 1)
	if area.X / scale < Layout.WINDOW_SIZE.X then
		scale = math.max(area.X / Layout.WINDOW_SIZE.X, 0.1)
	end
	return {
		scale = scale,
		size = Vector2.new(math.min(area.X / scale, 1400), math.min(area.Y / scale, Layout.WINDOW_SIZE.Y)),
		offsetY = 0,
	}
end

return Layout
