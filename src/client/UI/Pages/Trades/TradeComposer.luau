-- making a trade, like Roblox: pick who to trade with (someone in this server, or anyone by username), then pick up
-- to Config.Trade.MaxItems items from each inventory and send it. also used to counter a trade, starting from the
-- trade being countered (sides swapped, since you are now the one sending it).
-- hovering (or tapping) an item shows its full stats with an Inspect button.
-- props: inventory (your own), counter? (the trade being countered), onDone(), onInspectItem(item)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local SearchBox = require(script.Parent.Parent.Parent.Components.SearchBox)
local InventoryFilters = require(script.Parent.Parent.InventoryFilters)
local TradeParts = require(script.Parent.TradeParts)
local Trades = require(script.Parent.Parent.Parent.Parent.Controllers.Trades)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local MAX_ITEMS = Config.Trade.MaxItems
local OFFER_HEIGHT = 100
local FOOTER = 40
local SEARCH_HEIGHT = 30
local SHOWN = 60
local EMPTY_SET = {}

local function fail(message: string?)
	Sfx.play("error")
	Notifications.push(message or "Something went wrong", Theme.colors.bad)
end

local function entriesOf(items)
	local list = {}
	for _, item in items do
		local value = Valuation.value(item)
		table.insert(list, {
			item = item,
			value = value,
			valueText = Format.cash(value),
			tierId = ItemRegistry.tier(item.assetId).id,
			traits = Traits.of(item),
		})
	end
	return list
end

-- a small tile in the offer strip, click to take it back out
local function Chip(props)
	local item = props.item
	local hovered, setHovered = React.useState(false)
	local hover = TradeParts.useHover()
	local tier = ItemRegistry.tier(item.assetId)
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = if hovered then Theme.colors.panelLight else Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onRemove(item.uid)
		end,
		[React.Event.MouseEnter] = function(rbx)
			setHovered(true)
			if hover then
				hover.open(item, rbx)
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			if hover then
				hover.close()
			end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if hovered then Theme.colors.bad else tier.color,
			Transparency = 0.3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Thumb = e("ImageLabel", {
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 1, -10),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(item.assetId, 150),
			ImageTransparency = if hovered then 0.5 else 0,
		}),
		Remove = hovered and e(Text, {
			Size = UDim2.fromScale(1, 1),
			Text = "X",
			TextSize = 20,
			display = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.text,
		}) or nil,
	})
end

local function Offer(props)
	local chips = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in props.items do
		chips[item.uid] = e(Chip, { item = item, layoutOrder = index, onRemove = props.onRemove })
	end
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.new(0.5, -5, 0, OFFER_HEIGHT),
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Title = e(Text, {
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -20, 0, 20),
			Text = `{props.title}  ({#props.items}/{MAX_ITEMS})`,
			TextSize = 16,
			display = true,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 5),
			Size = UDim2.fromOffset(160, 20),
			Text = Format.cash(TradeParts.total(props.items)),
			TextSize = 14,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Chips = e("ScrollingFrame", {
			Position = UDim2.fromOffset(8, 30),
			Size = UDim2.new(1, -16, 0, 66),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, chips),
		Hint = #props.items == 0 and e(Text, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 62),
			Text = props.hint,
			TextSize = 13,
			TextColor3 = Theme.colors.textFaint,
		}) or nil,
	})
end

-- one inventory to pick from, with a search box. props: title, items, selected ({ [uid]: true }), onToggle(uid),
-- loading?, error?, anchorPoint?, position
local function Picker(props)
	local query, setQuery = React.useState("")
	local entries = React.useMemo(function()
		return entriesOf(props.items)
	end, { props.items })
	local filtered = React.useMemo(function()
		return InventoryFilters.apply(entries, { query = query, sort = "value_desc" }, EMPTY_SET, EMPTY_SET)
	end, { entries, query } :: { any })

	local tiles = {}
	for index = 1, math.min(#filtered, SHOWN) do
		local item = filtered[index].item
		tiles[item.uid] = e(TradeParts.Tile, {
			item = item,
			layoutOrder = index,
			selected = props.selected[item.uid] == true,
			onSelect = props.onToggle,
		})
	end

	local message = nil
	if props.loading then
		message = "Loading inventory..."
	elseif props.error then
		message = props.error
	elseif #props.items == 0 then
		message = "No items"
	elseif #filtered == 0 then
		message = "No items match"
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.new(0.5, -5, 1, -(OFFER_HEIGHT + FOOTER + 20)),
		BackgroundTransparency = 1,
	}, {
		Search = e(SearchBox, {
			size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
			value = query,
			placeholder = `Search {props.title}...`,
			onChange = setQuery,
		}),
		Items = e(Grid, {
			position = UDim2.fromOffset(0, SEARCH_HEIGHT + 6),
			size = UDim2.new(1, 0, 1, -(SEARCH_HEIGHT + 6 + (if #filtered > SHOWN then 18 else 0))),
			cellSize = UDim2.fromOffset(110, 140),
			cellPadding = UDim2.fromOffset(6, 6),
		}, tiles),
		Message = message and e(Text, {
			Position = UDim2.fromOffset(0, SEARCH_HEIGHT + 20),
			Size = UDim2.new(1, 0, 0, 30),
			Text = message,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
		More = #filtered > SHOWN and e(Text, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 16),
			Text = `Showing the top {SHOWN} of {#filtered}, search to find others`,
			TextSize = 12,
			TextColor3 = Theme.colors.textFaint,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
	})
end

-- step 1: who to trade with
local function PartnerPicker(props)
	local name, setName = React.useState("")
	local looking, setLooking = React.useState(false)
	local others, setOthers = React.useState({})

	React.useEffect(function()
		local function refresh()
			local list = {}
			for _, player in Players:GetPlayers() do
				if player ~= Players.LocalPlayer then
					table.insert(list, { userId = player.UserId, name = player.Name })
				end
			end
			table.sort(list, function(a, b)
				return a.name:lower() < b.name:lower()
			end)
			setOthers(list)
		end
		refresh()
		local added = Players.PlayerAdded:Connect(refresh)
		local removing = Players.PlayerRemoving:Connect(function()
			task.defer(refresh)
		end)
		return function()
			added:Disconnect()
			removing:Disconnect()
		end
	end, {})

	local function find()
		if looking or name == "" then
			return
		end
		setLooking(true)
		task.spawn(function()
			local result = Trades.action("lookup", { name = name })
			setLooking(false)
			if not result.ok then
				fail(result.err)
			elseif result.data.userId == Players.LocalPlayer.UserId then
				fail("You can't trade with yourself")
			else
				props.onPick(result.data)
			end
		end)
	end

	local cards = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 150),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in others do
		cards[tostring(entry.userId)] = e("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Text = "",
			[React.Event.Activated] = function()
				Sfx.play("tab")
				props.onPick(entry)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Avatar = e(TradeParts.Avatar, {
				userId = entry.userId,
				size = 84,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 16),
			}),
			Name = e(Text, {
				Position = UDim2.new(0, 8, 1, -38),
				Size = UDim2.new(1, -16, 0, 20),
				Text = entry.name,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Trade with anyone by username, even if they're offline",
			TextSize = 18,
			display = true,
		}),
		Name = e(SearchBox, {
			position = UDim2.fromOffset(0, 32),
			size = UDim2.new(1, -150, 0, 36),
			value = name,
			placeholder = "Username",
			onChange = setName,
		}),
		Find = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, 32),
			size = UDim2.fromOffset(140, 36),
			text = if looking then "Looking..." else "Find",
			color = Theme.colors.accent,
			disabled = looking or name == "",
			onClick = find,
		}),
		HereTitle = e(Text, {
			Position = UDim2.fromOffset(0, 86),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "In this server",
			TextSize = 16,
			display = true,
			TextColor3 = Theme.colors.textDim,
		}),
		Here = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 1, -112),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, cards),
		Nobody = #others == 0 and e(Text, {
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 0, 30),
			Text = "Nobody else is in this server, find someone by username above",
			TextColor3 = Theme.colors.textFaint,
		}) or nil,
	})
end

local function TradeComposer(props)
	local counter = props.counter
	local partner, setPartner = React.useState(
		if counter then { userId = counter.partnerId, name = counter.partnerName } else nil
	)
	-- selections are ordered uid lists. a counter starts from the trade (what you gave, what you got) minus anything
	-- you no longer own on your side
	local give, setGive = React.useState(function()
		local list = {}
		for _, item in if counter then counter.give else {} do
			if props.inventory[item.uid] then
				table.insert(list, item.uid)
			end
		end
		return list
	end)
	local get, setGet = React.useState(function()
		local list = {}
		for _, item in if counter then counter.get else {} do
			table.insert(list, item.uid)
		end
		return list
	end)
	local theirs, setTheirs = React.useState(nil)
	local loadError, setLoadError = React.useState(nil)
	local sending, setSending = React.useState(false)

	React.useEffect(function()
		if not partner then
			return nil
		end
		local alive = true
		setTheirs(nil)
		setLoadError(nil)
		task.spawn(function()
			local result = Trades.action("inventory", { userId = partner.userId })
			if not alive then
				return
			end
			if result.ok then
				setTheirs(result.data.items)
			else
				setLoadError(result.err or "Couldn't load their inventory")
			end
		end)
		return function()
			alive = false
		end
	end, { if partner then partner.userId else 0 })

	local mine = React.useMemo(function()
		local list = {}
		for _, item in props.inventory do
			table.insert(list, item)
		end
		return list
	end, { props.inventory })

	if not partner then
		return e(PartnerPicker, { onPick = setPartner })
	end
	local hoverProps = { onInspect = props.onInspectItem }
	local theirsByUid = {}
	for _, item in theirs or {} do
		theirsByUid[item.uid] = item
	end

	local function selectedItems(uids, byUid)
		local items = {}
		for _, uid in uids do
			local item = byUid[uid]
			if item then
				table.insert(items, item)
			end
		end
		return items
	end
	local giveItems = selectedItems(give, props.inventory)
	-- before their inventory loads, a counter shows the items from the trade
	local counterGet = {}
	for _, item in if counter then counter.get else {} do
		counterGet[item.uid] = item
	end
	local getItems = selectedItems(get, if theirs then theirsByUid else counterGet)

	local function setOf(uids)
		local set = {}
		for _, uid in uids do
			set[uid] = true
		end
		return set
	end

	local function toggler(list, setList)
		return function(uid: string)
			local index = table.find(list, uid)
			local nextList = table.clone(list)
			if index then
				table.remove(nextList, index)
			elseif #list >= MAX_ITEMS then
				fail(`Up to {MAX_ITEMS} items a side`)
				return
			else
				table.insert(nextList, uid)
			end
			setList(nextList)
		end
	end

	local giveValue, getValue = TradeParts.total(giveItems), TradeParts.total(getItems)
	local diff = getValue - giveValue
	local empty = #giveItems + #getItems == 0

	local function send()
		if sending or empty then
			return
		end
		setSending(true)
		task.spawn(function()
			local giveUids, getUids = {}, {}
			for _, item in giveItems do
				table.insert(giveUids, item.uid)
			end
			for _, item in getItems do
				table.insert(getUids, item.uid)
			end
			local result = if counter
				then Trades.action("counter", { id = counter.id, give = giveUids, get = getUids })
				else Trades.action("send", { userId = partner.userId, give = giveUids, get = getUids })
			setSending(false)
			if result.ok then
				Sfx.play("unlock")
				Notifications.push(`Trade sent to {partner.name}`, Color3.fromRGB(130, 210, 120))
				props.onDone()
			else
				fail(result.err)
			end
		end)
	end

	return e(TradeParts.HoverLayer, hoverProps, {
		Give = e(Offer, {
			position = UDim2.fromOffset(0, 0),
			title = "You give",
			items = giveItems,
			hint = "Pick items from your inventory below",
			onRemove = toggler(give, setGive),
		}),
		Get = e(Offer, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			title = `{partner.name} gives`,
			items = getItems,
			hint = "Pick items from their inventory below",
			onRemove = toggler(get, setGet),
		}),
		Mine = e(Picker, {
			position = UDim2.fromOffset(0, OFFER_HEIGHT + 10),
			title = "your items",
			items = mine,
			selected = setOf(give),
			onToggle = toggler(give, setGive),
		}),
		Theirs = e(Picker, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, OFFER_HEIGHT + 10),
			title = `{partner.name}'s items`,
			items = theirs or {},
			loading = theirs == nil and loadError == nil,
			error = loadError,
			selected = setOf(get),
			onToggle = toggler(get, setGet),
		}),
		Footer = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, FOOTER),
			BackgroundTransparency = 1,
		}, {
			Partner = e(TradeParts.Avatar, {
				userId = partner.userId,
				size = 36,
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.new(0, 0, 0.5, 0),
			}),
			With = e(Text, {
				Position = UDim2.fromOffset(46, 2),
				Size = UDim2.new(0.5, -46, 0, 18),
				Text = `{if counter then "Countering" else "Trading with"} {partner.name}`,
				TextSize = 15,
				weight = Enum.FontWeight.Bold,
			}),
			Summary = e(Text, {
				Position = UDim2.fromOffset(46, 21),
				Size = UDim2.new(0.5, -46, 0, 16),
				Text = if empty
					then "Add items to either side"
					else `You {if diff >= 0 then "gain" else "lose"} {Format.cash(math.abs(diff))}`,
				TextSize = 13,
				TextColor3 = if empty
					then Theme.colors.textFaint
					elseif diff >= 0 then Color3.fromRGB(130, 210, 120)
					else Color3.fromRGB(220, 110, 90),
			}),
			Change = not counter and e(Button, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -206, 0.5, 0),
				size = UDim2.fromOffset(150, 36),
				text = "Change player",
				textSize = 14,
				onClick = function()
					setPartner(nil)
					setGet({})
				end,
			}) or nil,
			Send = e(Button, {
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, 0, 0.5, 0),
				size = UDim2.fromOffset(200, 36),
				text = if sending then "Sending..." elseif counter then "Send counter" else "Send trade",
				color = Theme.colors.good,
				disabled = sending or empty,
				sound = false,
				onClick = send,
			}),
		}),
	})
end

return TradeComposer
