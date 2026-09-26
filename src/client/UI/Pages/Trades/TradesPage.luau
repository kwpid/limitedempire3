-- the trades window, like Roblox trades: Inbound / Outbound / Completed / Inactive tabs, a list of trades on the
-- left and the selected trade on the right (what you give, what you get, and accept / counter / decline / cancel).
-- props: trades, inventory (your own, to warn when you no longer have an item you'd give),
-- onCompose({ partner?, counter? }) opens the trade composer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local TabBar = require(script.Parent.Parent.Parent.Components.TabBar)
local TradeParts = require(script.Parent.TradeParts)
local Trades = require(script.Parent.Parent.Parent.Parent.Controllers.Trades)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local TAB_HEIGHT = 32
local LIST_WIDTH = 320
local ROW_HEIGHT = 58
local FOOTER = 44
local ARM_SECONDS = 4

local TABS = { "inbound", "outbound", "completed", "inactive" }
local TAB_NAMES = { inbound = "Inbound", outbound = "Outbound", completed = "Completed", inactive = "Inactive" }
local EMPTY = {
	inbound = "No trades waiting on you",
	outbound = "You have no trades waiting",
	completed = "No completed trades yet",
	inactive = "No inactive trades",
}

-- a button that needs a second click within a few seconds
local function ArmedButton(props)
	local armed, setArmed = React.useState(false)

	React.useEffect(function()
		if not armed then
			return nil
		end
		local thread = task.delay(ARM_SECONDS, setArmed, false)
		return function()
			pcall(task.cancel, thread)
		end
	end, { armed })

	React.useLayoutEffect(function()
		setArmed(false)
	end, { props.resetKey })

	return e(Button, {
		anchorPoint = props.anchorPoint,
		position = props.position,
		size = props.size,
		text = if armed then props.confirmText else props.text,
		textSize = 15,
		color = if armed then props.color:Lerp(Color3.new(1, 1, 1), 0.15) else props.color,
		disabled = props.disabled,
		onClick = function()
			if armed then
				setArmed(false)
				props.onConfirm()
			else
				setArmed(true)
			end
		end,
	})
end

local function Row(props)
	local trade = props.trade
	local hovered, setHovered = React.useState(false)
	local status = TradeParts.STATUS[trade.status] or TradeParts.STATUS.inactive
	local open = trade.status == "pending" or trade.status == "processing"
	local give, get = TradeParts.total(trade.give), TradeParts.total(trade.get)

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = if props.selected
			then Theme.colors.panelLight
			elseif hovered then Theme.colors.panel:Lerp(Theme.colors.panelLight, 0.5)
			else Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onSelect(trade.id)
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
			Color = if props.selected then Theme.colors.strokeLight else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Avatar = e(TradeParts.Avatar, {
			userId = trade.partnerId,
			size = 38,
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 10, 0.5, 0),
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(58, 10),
			Size = UDim2.new(1, -140, 0, 18),
			Text = trade.partnerName,
			TextSize = 15,
			weight = Enum.FontWeight.Bold,
		}),
		Summary = e(Text, {
			Position = UDim2.fromOffset(58, 31),
			Size = UDim2.new(1, -68, 0, 16),
			Text = `{Format.cash(give)} for {Format.cash(get)}  ·  {#trade.give} for {#trade.get} items`,
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
		}),
		Right = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 11),
			Size = UDim2.fromOffset(80, 16),
			Text = if open and trade.status == "pending"
				then TradeParts.ago(trade.createdAt)
				else status.text,
			TextSize = 12,
			TextColor3 = if open and trade.status == "pending" then Theme.colors.textFaint else status.color,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function Side(props)
	local tiles = {}
	for index, item in props.items do
		tiles[item.uid] = e(TradeParts.Tile, { item = item, layoutOrder = index })
	end
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Title = e(Text, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 20),
			Text = props.title,
			TextSize = 16,
			display = true,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.fromOffset(160, 20),
			Text = `{#props.items} items  ·  {Format.cash(TradeParts.total(props.items))}`,
			TextSize = 13,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Items = e(Grid, {
			position = UDim2.fromOffset(6, 32),
			size = UDim2.new(1, -8, 1, -36),
			cellSize = UDim2.fromOffset(98, 128),
			cellPadding = UDim2.fromOffset(6, 6),
		}, tiles),
		Empty = #props.items == 0 and e(Text, {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Nothing",
			TextColor3 = Theme.colors.textFaint,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
	})
end

local function Detail(props)
	local trade = props.trade
	local status = TradeParts.STATUS[trade.status] or TradeParts.STATUS.inactive
	local give, get = TradeParts.total(trade.give), TradeParts.total(trade.get)
	local diff = get - give
	local missing = false
	if trade.direction == "inbound" and trade.status == "pending" then
		for _, item in trade.give do
			if not props.inventory[item.uid] then
				missing = true
			end
		end
	end

	local subtitle = `{status.text}  ·  {if trade.direction == "inbound" then "sent to you" else "sent by you"} {TradeParts.ago(
		trade.createdAt
	)}`
	if trade.note then
		subtitle ..= `  ·  {trade.note}`
	end

	local buttons = {}
	local busy = props.busy
	if trade.status == "pending" and trade.direction == "inbound" then
		buttons.Accept = e(ArmedButton, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromOffset(170, 38),
			text = "Accept",
			confirmText = "Confirm accept",
			color = Theme.colors.good,
			disabled = busy or missing,
			resetKey = trade.id,
			onConfirm = function()
				props.run("accept", trade.id)
			end,
		})
		buttons.Counter = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -176, 0, 0),
			size = UDim2.fromOffset(120, 38),
			text = "Counter",
			textSize = 15,
			color = Theme.colors.accent,
			disabled = busy,
			onClick = function()
				props.onCounter(trade)
			end,
		})
		buttons.Decline = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -302, 0, 0),
			size = UDim2.fromOffset(120, 38),
			text = "Decline",
			textSize = 15,
			color = Theme.colors.bad,
			disabled = busy,
			onClick = function()
				props.run("decline", trade.id)
			end,
		})
	elseif trade.status == "pending" then
		buttons.Cancel = e(ArmedButton, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromOffset(170, 38),
			text = "Cancel trade",
			confirmText = "Confirm cancel",
			color = Theme.colors.bad,
			disabled = busy,
			resetKey = trade.id,
			onConfirm = function()
				props.run("cancel", trade.id)
			end,
		})
	end

	local footerText = nil
	if missing then
		footerText = "You no longer have all of the items you'd give"
	elseif trade.status == "processing" then
		footerText = "Accepted, the items are on their way"
	elseif trade.status == "pending" and trade.direction == "outbound" then
		footerText = `Waiting on {trade.partnerName}`
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, TAB_HEIGHT + 10),
		Size = UDim2.new(1, -(LIST_WIDTH + 10), 1, -(TAB_HEIGHT + 10)),
		BackgroundTransparency = 1,
	}, {
		Avatar = e(TradeParts.Avatar, { userId = trade.partnerId, size = 44, color = status.color }),
		Name = e(Text, {
			Position = UDim2.fromOffset(56, 2),
			Size = UDim2.new(1, -220, 0, 22),
			Text = trade.partnerName,
			TextSize = 20,
			display = true,
		}),
		Subtitle = e(Text, {
			Position = UDim2.fromOffset(56, 26),
			Size = UDim2.new(1, -56, 0, 16),
			Text = subtitle,
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
		}),
		Diff = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 4),
			Size = UDim2.fromOffset(200, 20),
			Text = `You {if diff >= 0 then "gain" else "lose"} {Format.cash(math.abs(diff))}`,
			TextSize = 14,
			TextColor3 = if diff >= 0 then Color3.fromRGB(130, 210, 120) else Color3.fromRGB(220, 110, 90),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Give = e(Side, {
			position = UDim2.fromOffset(0, 54),
			size = UDim2.new(0.5, -5, 1, -(54 + FOOTER + 8)),
			title = "You give",
			items = trade.give,
		}),
		Get = e(Side, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, 54),
			size = UDim2.new(0.5, -5, 1, -(54 + FOOTER + 8)),
			title = "You get",
			items = trade.get,
		}),
		Footer = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
		}, {
			Note = footerText and e(Text, {
				Size = UDim2.new(1, -440, 1, 0),
				Text = footerText,
				TextSize = 13,
				TextColor3 = if missing then Color3.fromRGB(220, 110, 90) else Theme.colors.textDim,
			}) or nil,
			Buttons = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, buttons),
		}),
	})
end

local function TradesPage(props)
	local tab, setTab = React.useState("inbound")
	local selectedId, setSelectedId = React.useState(nil)
	local busy, setBusy = React.useState(false)

	local byTab = React.useMemo(function()
		local groups = { inbound = {}, outbound = {}, completed = {}, inactive = {} }
		for _, trade in props.trades do
			table.insert(groups[TradeParts.tabOf(trade)], trade)
		end
		for id, group in groups do
			local key = if id == "inbound" or id == "outbound" then "createdAt" else "updatedAt"
			table.sort(group, function(a, b)
				return a[key] > b[key]
			end)
		end
		return groups
	end, { props.trades })

	local list = byTab[tab]
	local selected = nil
	for _, trade in list do
		if trade.id == selectedId then
			selected = trade
		end
	end
	selected = selected or list[1]

	local function run(action: string, id: string)
		if busy then
			return
		end
		setBusy(true)
		task.spawn(function()
			local result = Trades.action(action, { id = id })
			setBusy(false)
			if not result.ok then
				Sfx.play("error")
				Notifications.push(result.err or "Something went wrong", Theme.colors.bad)
			end
		end)
	end

	local tabs = {}
	for _, id in TABS do
		local count = #byTab[id]
		local showCount = (id == "inbound" or id == "outbound") and count > 0
		table.insert(tabs, { id = id, text = if showCount then `{TAB_NAMES[id]} ({count})` else TAB_NAMES[id] })
	end

	local rows = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 1) }),
	}
	for index, trade in list do
		rows[trade.id] = e(Row, {
			trade = trade,
			layoutOrder = index,
			selected = selected ~= nil and selected.id == trade.id,
			onSelect = setSelectedId,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Tabs = e(TabBar, {
			size = UDim2.new(1, -170, 0, TAB_HEIGHT),
			tabs = tabs,
			value = tab,
			onChange = function(id)
				setTab(id)
				setSelectedId(nil)
			end,
		}),
		New = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromOffset(160, TAB_HEIGHT),
			text = "New trade",
			textSize = 15,
			color = Theme.colors.good,
			onClick = function()
				props.onCompose({})
			end,
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
			Size = UDim2.new(0, LIST_WIDTH, 1, -(TAB_HEIGHT + 10)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
		Empty = #list == 0 and e(Text, {
			Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
			Text = `{EMPTY[tab]}\nTrades expire after {Config.Trade.ExpireDays} days, up to {Config.Trade.MaxItems} items a side.`,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
		}) or nil,
		Detail = selected and e(Detail, {
			trade = selected,
			inventory = props.inventory,
			busy = busy,
			run = run,
			onCounter = function(trade)
				props.onCompose({ counter = trade })
			end,
		}) or nil,
	})
end

return TradesPage
