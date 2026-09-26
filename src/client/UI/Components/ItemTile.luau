local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local TraitText = require(script.Parent.TraitText)
local Checkmark = require(script.Parent.Checkmark)
local TrackerBadge = require(script.Parent.TrackerBadge)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local function Corner(props)
	return e(TraitText, {
		trait = props.trait,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = props.text,
		TextSize = 11,
		TextColor3 = props.color,
		TextXAlignment = props.alignment,
		TextTruncate = Enum.TextTruncate.None,
		TextStrokeTransparency = 0.6,
		weight = Enum.FontWeight.Bold,
		ZIndex = 3,
	})
end

local FADE_IDLE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.45, 1),
	NumberSequenceKeypoint.new(1, 0.72),
})

local FADE_HOVER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.45, 1),
	NumberSequenceKeypoint.new(1, 0.62),
})

local function ItemTile(props)
	local hovered, setHovered = React.useState(false)
	local accent = props.accent or ItemRegistry.tier(props.assetId).color
	local info = ItemRegistry.get(props.assetId)
	local clickable = props.onSelect ~= nil

	local strokeColor = Theme.colors.stroke
	if props.selected then
		strokeColor = Theme.colors.text
	elseif hovered and clickable then
		strokeColor = Theme.colors.strokeLight
	end

	return e("TextButton", {
		Size = props.size,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Active = clickable,
		ClipsDescendants = true,
		[React.Event.Activated] = function()
			if props.onSelect then
				Sfx.play("tab")
				props.onSelect(props.id)
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = strokeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		RarityFade = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = if hovered and clickable then FADE_HOVER else FADE_IDLE,
			}),
		}),
		Thumbnail = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.new(1, -28, 1, -64),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(props.assetId, 150),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
		Title = e(Text, {
			Position = UDim2.new(0, 8, 1, -44),
			Size = UDim2.new(1, -16, 0, 16),
			Text = props.title or (info and info.name or "Unknown"),
			TextSize = 13,
			ZIndex = 2,
		}),
		Subtitle = e(Text, {
			Position = UDim2.new(0, 8, 1, -26),
			Size = UDim2.new(1, if props.equipped then -36 else -16, 0, 14),
			Text = props.subtitle or "",
			TextSize = 12,
			TextColor3 = props.subtitleColor or Theme.colors.textDim,
			ZIndex = 2,
		}),
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		Tracker = props.trackerCount and e(TrackerBadge, {
			count = props.trackerCount,
			anchorPoint = Vector2.new(0, 1),
			position = UDim2.new(0, 8, 1, -46),
			zIndex = 3,
		}),
		Equipped = props.equipped and e(Checkmark, {
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -7, 1, -9),
			size = 16,
			zIndex = 3,
		}),
		Badge = props.badgeText and e(Corner, {
			text = props.badgeText,
			color = props.badgeColor,
			trait = props.badgeTrait,
			position = UDim2.fromOffset(7, 5),
			alignment = Enum.TextXAlignment.Left,
		}),
		Tag = props.tagText and e(Corner, {
			text = props.tagText,
			color = props.tagColor,
			position = UDim2.new(1, -7, 0, 5),
			anchorPoint = Vector2.new(1, 0),
			alignment = Enum.TextXAlignment.Right,
		}),
	})
end

return React.memo(ItemTile)
