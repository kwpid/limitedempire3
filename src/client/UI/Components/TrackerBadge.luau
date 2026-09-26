-- stat tracker count pill: a small orange counter in a monospace font, like a digital readout.
-- props: count, textSize (default 11), position, anchorPoint, layoutOrder, zIndex, assetId (optional thumbnail
-- in front of the count, used on overheads to tell trackers apart)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

local function TrackerBadge(props)
	local textSize = props.textSize or 11
	local height = textSize + 6
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(24, 16, 8),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		Stroke = e("UIStroke", {
			Color = Theme.colors.tracker,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, if props.assetId then 2 else 5),
			PaddingRight = UDim.new(0, 5),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Thumbnail = props.assetId and e("ImageLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(height - 2, height - 2),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(props.assetId, 150),
			ZIndex = props.zIndex,
		}),
		Count = e("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = Format.commas(props.count or 0),
			FontFace = Theme.mono(),
			TextSize = textSize,
			TextColor3 = Theme.colors.tracker,
			ZIndex = props.zIndex,
		}),
	})
end

return React.memo(TrackerBadge)
