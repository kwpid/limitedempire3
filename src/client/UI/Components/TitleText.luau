-- a player title in all caps with its color, and for glow titles a soft colored halo around the letters (two
-- strokes: a wide faint one behind, a thin bright one on the text) that breathes slowly when "animatedText" is on.
-- renders nothing for "none" unless showNone is set.
-- props: titleId, textSize (default 14), size, position, anchorPoint, layoutOrder, alignment, showNone, zIndex

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Titles = require(ReplicatedStorage.Shared.Titles)
local Theme = require(script.Parent.Parent.Theme)
local clock = require(script.Parent.Parent.Clock)
local useSetting = require(script.Parent.Parent.Hooks.useSetting)

local e = React.createElement

local function strokeWith(glowColor, props)
	local isSequence = typeof(glowColor) == "ColorSequence"
	return e("UIStroke", {
		Color = if isSequence then Color3.new(1, 1, 1) else glowColor,
		Thickness = props.thickness,
		Transparency = props.transparency,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, {
		Gradient = if isSequence then e("UIGradient", { Color = glowColor }) else nil,
	})
end

local function TitleText(props)
	local animated = useSetting("animatedText")
	local title = Titles.get(props.titleId)
	if not title or (title.id == Titles.NONE and not props.showNone) then
		return nil
	end

	local textSize = props.textSize or 14
	local function label(extra)
		local base = {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = string.upper(title.name),
			FontFace = Theme.display(Enum.FontWeight.Bold),
			TextSize = textSize,
			TextColor3 = title.color,
			TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
			ZIndex = props.zIndex,
		}
		for key, value in extra do
			base[key] = value
		end
		return base
	end

	local children = {}
	if title.glow and title.glowColor then
		local haloTransparency = if animated
			then clock:map(function(t)
				return 0.62 + math.sin(t * 2) * 0.12
			end)
			else 0.62
		children.Halo = e("TextLabel", label({ TextTransparency = 0.55, TextColor3 = Color3.new(1, 1, 1) }), {
			Gradient = if typeof(title.glowColor) == "ColorSequence"
				then e("UIGradient", { Color = title.glowColor })
				else e("UIGradient", { Color = ColorSequence.new(title.glowColor) }),
			Stroke = strokeWith(title.glowColor, {
				thickness = math.max(2, textSize * 0.22),
				transparency = haloTransparency,
			}),
		})
		children.Text = e("TextLabel", label({}), {
			Stroke = strokeWith(title.glowColor, { thickness = 1.2, transparency = 0.25 }),
		})
	else
		children.Text = e(
			"TextLabel",
			label({
				TextStrokeTransparency = 0.7,
			})
		)
	end

	return e("Frame", {
		Size = props.size or UDim2.new(1, 0, 0, textSize + 4),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, children)
end

return TitleText
