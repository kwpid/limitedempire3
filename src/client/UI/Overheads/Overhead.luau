local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Ranks = require(ReplicatedStorage.Shared.Progress.Ranks)
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
local TRACKERS_PER_ROW = 3
local TRACKER_TEXT_SIZE = 12
local TRACKER_ROW_HEIGHT = TRACKER_TEXT_SIZE + 7
local TRACKER_ROW_GAP = 3

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

-- "@name  ·  Lv 12  ·  Gold II" with the level and rank tinted (ProgressService sets the Level and Rank attributes)
local function usernameLine(player: Player, level: any, rankName: any): string
	local parts = { "@" .. player.Name }
	if type(level) == "number" then
		table.insert(parts, `<font color="#78BEFF">Lv {level}</font>`)
	end
	if type(rankName) == "string" then
		local color = Theme.colors.textDim
		for _, tier in Ranks.tiers do
			if string.find(rankName, tier.name, 1, true) == 1 then
				color = tier.color
			end
		end
		table.insert(parts, `<font color="#{color:ToHex()}">{rankName}</font>`)
	end
	return table.concat(parts, "  ·  ")
end

local function Overhead(props)
	local player: Player = props.player
	local styleId = usePlayerAttribute("NameStyle", player)
	local value = usePlayerValue(player)
	local trackersRaw = usePlayerAttribute("StatTrackers", player)
	local titleId = usePlayerAttribute("Title", player)
	local level = usePlayerAttribute("Level", player)
	local rankName = usePlayerAttribute("Rank", player)
	local trackers = React.useMemo(function()
		return parseTrackers(trackersRaw)
	end, { trackersRaw })

	-- fixed size rows instead of a wrapping auto sized frame: the overhead's UIScale starts at 0, and an auto sized
	-- frame measured at that scale stayed 0 tall until its contents changed (trackers were hidden after rejoining
	-- until a case was opened)
	local rowCount = math.ceil(#trackers / TRACKERS_PER_ROW)
	local trackerRows = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, TRACKER_ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for row = 1, rowCount do
		local badges = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index = (row - 1) * TRACKERS_PER_ROW + 1, math.min(row * TRACKERS_PER_ROW, #trackers) do
			local tracker = trackers[index]
			badges["Tracker" .. index] = e(TrackerBadge, {
				layoutOrder = index,
				count = tracker.count,
				assetId = tracker.assetId,
				textSize = TRACKER_TEXT_SIZE,
			})
		end
		trackerRows["Row" .. row] = e("Frame", {
			LayoutOrder = row,
			Size = UDim2.new(1, 0, 0, TRACKER_ROW_HEIGHT),
			BackgroundTransparency = 1,
		}, badges)
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
		-- only drawn once the scale is known, so auto sized parts (tracker badges, the value pill) are measured at
		-- their real size instead of at scale 0
		Content = scale > 0 and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { Scale = scale }),
			Trackers = if rowCount > 0
				then e("Frame", {
					LayoutOrder = 0,
					Size = UDim2.new(
						1,
						0,
						0,
						rowCount * TRACKER_ROW_HEIGHT + (rowCount - 1) * TRACKER_ROW_GAP
					),
					BackgroundTransparency = 1,
				}, trackerRows)
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
				Text = usernameLine(player, level, rankName),
				RichText = true,
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
