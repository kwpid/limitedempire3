local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local NameLabel = require(script.Parent.Parent.Components.NameLabel)
local TrackerBadge = require(script.Parent.Parent.Components.TrackerBadge)
local TitleText = require(script.Parent.Parent.Components.TitleText)
local usePlayerAttribute = require(script.Parent.Parent.Hooks.usePlayerAttribute)
local usePlayerValue = require(script.Parent.Parent.Hooks.usePlayerValue)

local e = React.createElement

-- the overhead is laid out at this pixel size, then scaled to match the billboard's on-screen size
local DESIGN_WIDTH = 260
local DESIGN_HEIGHT = 74

-- the server mirrors equipped stat trackers to this attribute as json: { { a = assetId string, n = count } }
local function parseTrackers(raw: any): { { assetId: number, count: number } }
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local list = {}
	for _, entry in decoded do
		local assetId = tonumber(entry.a)
		if assetId and type(entry.n) == "number" then
			table.insert(list, { assetId = assetId, count = entry.n })
		end
	end
	return list
end

local function Overhead(props)
	local player: Player = props.player
	local styleId = usePlayerAttribute("NameStyle", player)
	local value = usePlayerValue(player)
	local trackersRaw = usePlayerAttribute("StatTrackers", player)
	local titleId = usePlayerAttribute("Title", player)
	local trackers = React.useMemo(function()
		return parseTrackers(trackersRaw)
	end, { trackersRaw })

	local trackerChildren = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 4),
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tracker in trackers do
		trackerChildren["Tracker" .. index] = e(TrackerBadge, {
			layoutOrder = index,
			count = tracker.count,
			assetId = tracker.assetId,
			textSize = 12,
		})
	end
	local billboardRef = React.useRef(nil :: BillboardGui?)
	local scale, setScale = React.useState(0)

	React.useEffect(function()
		local billboard = billboardRef.current
		if not billboard then
			return
		end
		local function update()
			setScale(billboard.AbsoluteSize.X / DESIGN_WIDTH)
		end
		update()
		local connection = billboard:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, {})

	local widthStuds = Config.Overhead.WidthStuds

	return e("BillboardGui", {
		ref = billboardRef,
		Adornee = props.head,
		Size = UDim2.fromScale(widthStuds, widthStuds * DESIGN_HEIGHT / DESIGN_WIDTH),
		StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = Config.Overhead.MaxDistance,
		ClipsDescendants = false,
	}, {
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { Scale = scale }),
			Trackers = if #trackers > 0
				then e("Frame", {
					LayoutOrder = 0,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, trackerChildren)
				else nil,
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Name = e(NameLabel, {
				layoutOrder = 2,
				size = UDim2.new(1, 0, 0, 24),
				text = player.DisplayName,
				styleId = styleId,
				textSize = 22,
			}),
			Title = e(TitleText, {
				layoutOrder = 1,
				titleId = titleId,
				textSize = 14,
			}),
			Username = e(Text, {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 14),
				Text = "@" .. player.Name,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextStrokeTransparency = 0.6,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Value = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.colors.topbar,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", {
					Color = Theme.colors.cash,
					Transparency = 0.55,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
				Label = e(Text, {
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = Format.cash(value),
					TextSize = 14,
					TextColor3 = Theme.colors.cash,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.None,
					display = true,
				}),
			}),
		}),
	})
end

return React.memo(Overhead)
