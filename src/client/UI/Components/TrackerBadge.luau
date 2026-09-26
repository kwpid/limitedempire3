-- stat tracker badge: an orange bar chart icon and the count in a monospace font, like a digital readout.
-- props: count, textSize (default 11), title (optional text before the count, e.g. "Stat Tracker"), label
-- (optional text after it, e.g. "cases opened"), assetId (optional item thumbnail in front, used on overheads to
-- tell trackers apart), position, anchorPoint, layoutOrder, zIndex

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

-- three rising bars, drawn at any size
local function Icon(props)
	local size = props.size
	local bars = {}
	for index, height in { 0.45, 0.7, 1 } do
		bars["Bar" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale((index - 1) * 0.37, 1),
			Size = UDim2.fromScale(0.26, height),
			BackgroundColor3 = Theme.colors.tracker,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		})
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, bars)
end

local function Label(props)
	return e("TextLabel", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(0, props.height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = props.text,
		FontFace = props.font,
		TextSize = props.textSize,
		TextColor3 = props.color,
		ZIndex = props.zIndex,
	})
end

local function TrackerBadge(props)
	local textSize = props.textSize or 11
	local height = textSize + 7
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(28, 18, 8),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		Stroke = e("UIStroke", {
			Color = Theme.colors.tracker,
			Transparency = 0.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, if props.assetId then 2 else 5),
			PaddingRight = UDim.new(0, 6),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Thumbnail = props.assetId and e("ImageLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(height - 2, height - 2),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(props.assetId, 150),
			ZIndex = props.zIndex,
		}),
		Icon = e(Icon, {
			layoutOrder = 2,
			size = math.floor(textSize * 0.9),
			zIndex = props.zIndex,
		}),
		Title = props.title and e(Label, {
			layoutOrder = 3,
			text = string.upper(props.title),
			font = Theme.display(Enum.FontWeight.Bold),
			textSize = textSize,
			color = Theme.colors.tracker,
			height = height,
			zIndex = props.zIndex,
		}),
		Count = e(Label, {
			layoutOrder = 4,
			text = Format.commas(props.count or 0),
			font = Theme.mono(),
			textSize = textSize,
			color = Color3.fromRGB(255, 196, 120),
			height = height,
			zIndex = props.zIndex,
		}),
		Suffix = props.label and e(Label, {
			layoutOrder = 5,
			text = props.label,
			font = Theme.font(Enum.FontWeight.Medium),
			textSize = textSize - 1,
			color = Theme.colors.textDim,
			height = height,
			zIndex = props.zIndex,
		}),
	})
end

return React.memo(TrackerBadge)
