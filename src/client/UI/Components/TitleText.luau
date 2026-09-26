-- a player title in all caps with its color, and for glow titles a subtle colored halo around the letters (a
-- faint wide stroke behind and a light thin one on the text) that breathes slowly when "animatedText" is on.
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
				return 0.8 + math.sin(t * 1.6) * 0.06
			end)
			else 0.8
		-- the halo's text sits right under the real text (a text stroke fades with its text, so it can't be hidden)
		children.Halo = e("TextLabel", label({}), {
			Stroke = strokeWith(title.glowColor, {
				thickness = math.max(1.5, textSize * 0.14),
				transparency = haloTransparency,
			}),
		})
		children.Text = e("TextLabel", label({}), {
			Stroke = strokeWith(title.glowColor, { thickness = 1, transparency = 0.55 }),
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
