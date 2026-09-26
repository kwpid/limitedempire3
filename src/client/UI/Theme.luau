local Theme = {}

Theme.colors = {
	backdrop = Color3.fromRGB(10, 12, 14),
	topbar = Color3.fromRGB(19, 22, 25),
	window = Color3.fromRGB(27, 31, 35),
	panel = Color3.fromRGB(35, 40, 45),
	panelLight = Color3.fromRGB(46, 52, 58),
	inset = Color3.fromRGB(21, 24, 27),
	stroke = Color3.fromRGB(58, 65, 72),
	strokeLight = Color3.fromRGB(88, 97, 106),
	text = Color3.fromRGB(222, 226, 230),
	textDim = Color3.fromRGB(139, 148, 156),
	textFaint = Color3.fromRGB(96, 104, 112),
	accent = Color3.fromRGB(76, 107, 145),
	good = Color3.fromRGB(88, 138, 42),
	bad = Color3.fromRGB(160, 52, 52),
	cash = Color3.fromRGB(229, 186, 71),
	marker = Color3.fromRGB(245, 185, 28),
	special = Color3.fromRGB(228, 174, 57),
	tracker = Color3.fromRGB(255, 142, 44),
}

Theme.radius = UDim.new(0, 2)

local BODY = "rbxasset://fonts/families/GothamSSm.json"
local DISPLAY = "rbxasset://fonts/families/Oswald.json"
local MONO = "rbxasset://fonts/families/RobotoMono.json"

function Theme.font(weight: Enum.FontWeight?): Font
	return Font.new(BODY, weight or Enum.FontWeight.Medium)
end

function Theme.display(weight: Enum.FontWeight?): Font
	return Font.new(DISPLAY, weight or Enum.FontWeight.Medium)
end

function Theme.mono(weight: Enum.FontWeight?): Font
	return Font.new(MONO, weight or Enum.FontWeight.Bold)
end

return Theme
