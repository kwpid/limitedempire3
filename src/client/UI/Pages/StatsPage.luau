-- the Stats for Nerds tab: every lifetime stat (Shared.PlayerStats) as cards by group, a few worked-out rates, this
-- session so far (Controllers/Session) and live performance numbers.
-- props: stats, cash

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local PlayerStats = require(Shared.PlayerStats)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Session = require(script.Parent.Parent.Parent.Controllers.Session)

local e = React.createElement

local ROW_HEIGHT = 26
local CARD_GAP = 10
local COLUMNS = 3
local GOOD = Color3.fromRGB(130, 210, 120)
local BAD = Color3.fromRGB(220, 110, 90)

local function percent(part: number, whole: number): string
	if whole <= 0 then
		return "-"
	end
	return string.format("%.1f%%", part / whole * 100)
end

local function signedCash(n: number): string
	return (if n >= 0 then "+" else "-") .. Format.cash(math.abs(n))
end

local function duration(seconds: number): string
	seconds = math.floor(seconds)
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m {seconds % 60}s`
end

local function statValue(stat, stats): (string, Color3?)
	local value = stats[stat.id] or 0
	if stat.format == "cash" then
		return Format.cash(value), Theme.colors.cash
	elseif stat.format == "item" then
		local info = value ~= 0 and ItemRegistry.get(value)
		return if info then info.name else "-", nil
	end
	return Format.commas(value), nil
end

-- worked-out rows added under a group's stats
local function extras(group: string, stats): { { label: string, value: string, color: Color3? } }
	local function n(id)
		return stats[id] or 0
	end
	if group == "Cases" then
		local net = n("unboxedValue") - n("spent")
		return {
			{ label = "Unboxed vs spent", value = signedCash(net), color = if net >= 0 then GOOD else BAD },
			{ label = "Average unbox", value = if n("opened") > 0 then Format.cash(n("unboxedValue") / n("opened")) else "-" },
		}
	elseif group == "Games" then
		return {
			{ label = "Upgrade win rate", value = percent(n("upgradesWon"), n("upgrades")) },
			{ label = "Battle win rate", value = percent(n("battlesWon"), n("battles")) },
		}
	elseif group == "Cash games" then
		local net = n("cashWon") - n("cashWagered")
		return {
			{ label = "Net", value = signedCash(net), color = if net >= 0 then GOOD else BAD },
			{ label = "Returned", value = percent(n("cashWon"), n("cashWagered")) },
		}
	end
	return {}
end

local function Row(props)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
	}, {
		Line = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.colors.stroke,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
		}),
		Label = e(Text, {
			Size = UDim2.fromScale(0.58, 1),
			Text = props.label,
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
		}),
		Value = e(Text, {
			Position = UDim2.fromScale(0.58, 0),
			Size = UDim2.fromScale(0.42, 1),
			Text = props.value,
			TextSize = 13,
			TextColor3 = props.color or Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
			weight = Enum.FontWeight.Bold,
		}),
	})
end

local function Card(props)
	local rows = {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, row in props.rows do
		rows["Row" .. index] = e(Row, { layoutOrder = index, label = row.label, value = row.value, color = row.color })
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Accent = e("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = props.color or Theme.colors.accent,
			BorderSizePixel = 0,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Title = e(Text, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Text = props.title,
			TextSize = 17,
			display = true,
		}),
		Rows = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, rows),
	})
end

-- frames per second, ping and memory, sampled twice a second
local function usePerformance()
	local perf, setPerf = React.useState({ fps = 0, ping = 0, memory = 0 })
	React.useEffect(function()
		local frames, since = 0, os.clock()
		local connection = RunService.RenderStepped:Connect(function()
			frames += 1
			local elapsed = os.clock() - since
			if elapsed >= 0.5 then
				local okPing, ping = pcall(function()
					return Players.LocalPlayer:GetNetworkPing() * 1000
				end)
				local okMemory, memory = pcall(function()
					return StatsService:GetTotalMemoryUsageMb()
				end)
				setPerf({
					fps = frames / elapsed,
					ping = if okPing then ping else 0,
					memory = if okMemory then memory else 0,
				})
				frames, since = 0, os.clock()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return perf
end

local GROUP_COLORS = {
	Cases = Color3.fromRGB(245, 185, 28),
	Items = Color3.fromRGB(136, 71, 255),
	Selling = Theme.colors.cash,
	Games = Color3.fromRGB(235, 95, 95),
	["Cash games"] = Color3.fromRGB(245, 160, 60),
	Trading = Color3.fromRGB(60, 200, 170),
	Income = Color3.fromRGB(130, 210, 120),
}

local function StatsPage(props)
	local stats = props.stats or {}
	local perf = usePerformance()
	local session = Session.get()

	local cards = {}
	-- session and performance first, then every group of lifetime stats
	local sessionRows = { { label = "Time played", value = duration(os.clock() - session.startedAt) } }
	if session.stats then
		local opened = (stats.opened or 0) - (session.stats.opened or 0)
		local cashChange = (props.cash or 0) - (session.cash or 0)
		table.insert(sessionRows, { label = "Cases opened", value = Format.commas(opened) })
		table.insert(sessionRows, {
			label = "Cash change",
			value = signedCash(cashChange),
			color = if cashChange >= 0 then GOOD else BAD,
		})
	end
	table.insert(cards, { title = "This session", color = Theme.colors.accent, rows = sessionRows })
	table.insert(cards, {
		title = "Performance",
		color = Theme.colors.strokeLight,
		rows = {
			{
				label = "FPS",
				value = string.format("%d", perf.fps),
				color = if perf.fps >= 50 then GOOD elseif perf.fps >= 30 then Theme.colors.marker else BAD,
			},
			{
				label = "Ping",
				value = string.format("%d ms", perf.ping),
				color = if perf.ping <= 120 then GOOD elseif perf.ping <= 250 then Theme.colors.marker else BAD,
			},
			{ label = "Memory", value = string.format("%d MB", perf.memory) },
		},
	})
	for _, group in PlayerStats.groups do
		local rows = {}
		for _, stat in PlayerStats.list do
			if stat.group == group then
				local value, color = statValue(stat, stats)
				table.insert(rows, { label = stat.label, value = value, color = color })
			end
		end
		for _, row in extras(group, stats) do
			table.insert(rows, row)
		end
		table.insert(cards, { title = group, color = GROUP_COLORS[group], rows = rows })
	end

	-- cards go into columns in turn, so each column scrolls as one list
	local columns = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	}
	for column = 1, COLUMNS do
		local children = {
			Layout = e("UIListLayout", { Padding = UDim.new(0, CARD_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		for index = column, #cards, COLUMNS do
			local card = cards[index]
			children["Card" .. index] = e(Card, {
				layoutOrder = index,
				title = card.title,
				color = card.color,
				rows = card.rows,
			})
		end
		columns["Column" .. column] = e("Frame", {
			LayoutOrder = column,
			Size = UDim2.new(1 / COLUMNS, -CARD_GAP * (COLUMNS - 1) / COLUMNS, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, children)
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, columns)
end

return StatsPage
