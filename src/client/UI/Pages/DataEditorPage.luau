-- admin panel "Player Data" tab: load any player's saved data by user id (online here or offline), browse their
-- inventory and fix it: spawn items (catalog or custom), edit an item's traits / float / serial / stat tracker,
-- delete items, set cash and unlock or lock titles and name styles. every change goes to the server (DataEditor)
-- which sends back the updated data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local NameStyles = require(Shared.Visuals.NameStyles)
local Titles = require(Shared.Titles)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Components.Grid)
local ItemTile = require(script.Parent.Parent.Components.ItemTile)
local SearchBox = require(script.Parent.Parent.Components.SearchBox)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)

local e = React.createElement

local HEADER = 34
local PANEL_WIDTH = 370
local WHERE_TEXT = {
	here = "online in this server (live edit)",
	offline = "offline (edits save to their profile)",
	elsewhere = "in another server (view only)",
}

-- react does not pass a prop named "ref" to function components, so the TextBox ref comes in as inputRef
local function Box(props)
	return e("TextBox", {
		ref = props.inputRef,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size or UDim2.fromOffset(120, 28),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = props.placeholder or "",
		PlaceholderColor3 = Theme.colors.textFaint,
		Text = props.text or "",
		TextColor3 = Theme.colors.text,
		FontFace = Theme.font(Enum.FontWeight.Medium),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
	})
end

local function Chip(props)
	return e(Button, {
		layoutOrder = props.layoutOrder,
		size = UDim2.fromOffset(props.width or 80, 24),
		text = props.text,
		textSize = 11,
		color = if props.active then (props.color or Theme.colors.accent) else nil,
		disabled = props.disabled,
		onClick = props.onClick,
	})
end

-- a row of buttons or boxes that wraps onto more lines and grows to fit them, so nothing overlaps the next row.
-- minHeight is the height of one line
local function wrapRow(children, minHeight: number, layoutOrder: number?)
	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return e("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, minHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, children)
end

local function Label(props)
	return e(Text, {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, props.height or 16),
		AutomaticSize = if props.wrapped then Enum.AutomaticSize.Y else nil,
		Text = props.text,
		TextSize = props.textSize or 12,
		TextColor3 = props.color or Theme.colors.textFaint,
		display = props.display,
		TextWrapped = props.wrapped,
		TextTruncate = if props.wrapped then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
	})
end

-- up to two traits, clicking a third replaces the older pick
local function TraitPicker(props)
	local chips = {}
	for index, trait in Traits.list do
		local active = table.find(props.value, trait.id) ~= nil
		chips[trait.id] = e(Chip, {
			layoutOrder = index,
			text = trait.name,
			width = 84,
			active = active,
			onClick = function()
				local nextValue = table.clone(props.value)
				local at = table.find(nextValue, trait.id)
				if at then
					table.remove(nextValue, at)
				elseif #nextValue < 2 then
					table.insert(nextValue, trait.id)
				else
					nextValue = { nextValue[2], trait.id }
				end
				props.onChange(nextValue)
			end,
		})
	end
	return wrapRow(chips, 24, props.layoutOrder)
end

local function readNumber(ref): number?
	local box = ref.current
	if not box then
		return nil
	end
	local text = box.Text:gsub("[,%s]", "")
	if text == "" then
		return nil
	end
	return tonumber(text)
end

local function Section(props)
	local children = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Title = e(
			Label,
			{
				layoutOrder = 0,
				text = props.title,
				textSize = 16,
				height = 20,
				color = Theme.colors.text,
				display = true,
			}
		),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, children)
end

-- editor for the selected item, remounted per item (keyed by uid) so the boxes start from its current values
local function ItemEditor(props)
	local item = props.item
	local traits, setTraits = React.useState(Traits.of(item))
	local armed, setArmed = React.useState(false)
	local floatRef = React.useRef(nil)
	local serialRef = React.useRef(nil)
	local trackerRef = React.useRef(nil)
	local info = ItemRegistry.get(item.assetId)
	local band = Condition.fromFloat(item.float)

	return e(Section, { layoutOrder = 1, title = "Selected item" }, {
		Name = e(Label, {
			layoutOrder = 1,
			text = Traits.fullName(Traits.of(item), info and info.name or `Unknown asset {item.assetId}`),
			textSize = 14,
			height = 18,
			color = Theme.colors.text,
		}),
		Meta = e(Label, {
			layoutOrder = 2,
			text = `{Format.cash(Valuation.value(item))}  ·  {band.name}  ·  #{item.serial}  ·  {if ItemRegistry.isCustom(
					item.assetId
				)
				then "custom"
				else "catalog"} {item.assetId}`,
		}),
		Uid = e(Label, { layoutOrder = 3, text = `uid {item.uid}` }),
		TraitsLabel = e(Label, { layoutOrder = 4, text = "Traits (none selected = no traits)" }),
		Traits = e(TraitPicker, { layoutOrder = 5, value = traits, onChange = setTraits }),
		Fields = wrapRow({
			Float = e(
				Box,
				{
					layoutOrder = 1,
					inputRef = floatRef,
					size = UDim2.fromOffset(106, 28),
					placeholder = "float",
					text = tostring(item.float),
				}
			),
			Serial = e(
				Box,
				{
					layoutOrder = 2,
					inputRef = serialRef,
					size = UDim2.fromOffset(106, 28),
					placeholder = "serial",
					text = tostring(item.serial),
				}
			),
			Tracker = e(Box, {
				layoutOrder = 3,
				inputRef = trackerRef,
				size = UDim2.fromOffset(106, 28),
				placeholder = "tracker count",
				text = if item.tracker then tostring(item.tracker.opens) else "",
			}),
		}, 28, 6),
		Hint = e(Label, {
			layoutOrder = 7,
			text = "Float 0 to 0.999999. Tracker count empty = no stat tracker.",
			wrapped = true,
		}),
		Buttons = wrapRow({
			Save = e(Button, {
				layoutOrder = 1,
				size = UDim2.fromOffset(170, 32),
				text = "Save changes",
				textSize = 14,
				color = Theme.colors.good,
				disabled = props.pending or props.readOnly,
				onClick = function()
					local tracker = readNumber(trackerRef)
					props.run("dataEditItem", {
						uid = item.uid,
						traits = traits,
						float = readNumber(floatRef),
						serial = readNumber(serialRef),
						tracker = if tracker then tracker else false,
					})
				end,
			}),
			Delete = e(Button, {
				layoutOrder = 2,
				size = UDim2.fromOffset(150, 32),
				text = if armed then "Click to confirm" else "Delete item",
				textSize = 14,
				color = Theme.colors.bad,
				disabled = props.pending or props.readOnly,
				onClick = function()
					if not armed then
						setArmed(true)
						task.delay(3, setArmed, false)
						return
					end
					props.run("dataRemoveItems", { uids = { item.uid } })
				end,
			}),
		}, 32, 8),
	})
end

local function SpawnSection(props)
	local traits, setTraits = React.useState({})
	local tracker, setTracker = React.useState(false)
	local assetRef = React.useRef(nil)
	local countRef = React.useRef(nil)
	local floatRef = React.useRef(nil)
	local serialRef = React.useRef(nil)

	local customChips = {}
	local order = 0
	for assetId, info in ItemRegistry.custom() do
		order += 1
		customChips[tostring(assetId)] = e(Chip, {
			layoutOrder = order,
			text = info.name,
			width = 160,
			onClick = function()
				if assetRef.current then
					assetRef.current.Text = tostring(assetId)
				end
			end,
		})
	end

	return e(Section, { layoutOrder = 2, title = "Spawn item" }, {
		Ids = wrapRow({
			Asset = e(
				Box,
				{ layoutOrder = 1, inputRef = assetRef, size = UDim2.fromOffset(200, 28), placeholder = "asset id" }
			),
			Count = e(
				Box,
				{ layoutOrder = 2, inputRef = countRef, size = UDim2.fromOffset(70, 28), placeholder = "count 1" }
			),
		}, 28, 1),
		CustomLabel = if order > 0
			then e(Label, { layoutOrder = 2, text = "Custom items (click to fill the asset id)" })
			else nil,
		Custom = if order > 0 then wrapRow(customChips, 24, 3) else nil,
		TraitsLabel = e(Label, { layoutOrder = 4, text = "Traits" }),
		Traits = e(TraitPicker, { layoutOrder = 5, value = traits, onChange = setTraits }),
		Fields = wrapRow({
			Float = e(
				Box,
				{ layoutOrder = 1, inputRef = floatRef, size = UDim2.fromOffset(110, 28), placeholder = "float (random)" }
			),
			Serial = e(
				Box,
				{ layoutOrder = 2, inputRef = serialRef, size = UDim2.fromOffset(110, 28), placeholder = "serial (next)" }
			),
			Tracker = e(Chip, {
				layoutOrder = 3,
				text = "Stat Tracker",
				width = 110,
				active = tracker,
				onClick = function()
					setTracker(not tracker)
				end,
			}),
		}, 28, 6),
		Spawn = e(Button, {
			layoutOrder = 7,
			size = UDim2.new(1, 0, 0, 32),
			text = "Spawn into their inventory",
			textSize = 14,
			color = Theme.colors.good,
			disabled = props.pending or props.readOnly,
			onClick = function()
				local assetId = readNumber(assetRef)
				if not assetId then
					Notifications.push("Enter an asset id", Theme.colors.bad)
					return
				end
				props.run("dataAddItems", {
					assetId = assetId,
					count = readNumber(countRef) or 1,
					traits = traits,
					float = readNumber(floatRef),
					serial = readNumber(serialRef),
					tracker = tracker,
				})
			end,
		}),
	})
end

local function CosmeticsSection(props)
	local snapshot = props.snapshot
	local function unlockedSet(kind: string)
		local set = {}
		local entry = snapshot.cosmetics and snapshot.cosmetics[kind]
		for _, id in entry and entry.unlocked or {} do
			set[id] = true
		end
		return set
	end

	local function chips(kind: string, list)
		local unlocked = unlockedSet(kind)
		local children = {}
		for index, entry in list do
			if entry.grant then
				continue
			end
			children[entry.id] = e(Chip, {
				layoutOrder = index,
				text = entry.name,
				width = 100,
				active = unlocked[entry.id] == true,
				color = Theme.colors.good,
				disabled = props.pending or props.readOnly,
				onClick = function()
					props.run("dataCosmetic", { kind = kind, id = entry.id, unlocked = not unlocked[entry.id] })
				end,
			})
		end
		return children
	end

	return e(Section, { layoutOrder = 3, title = "Unlocked cosmetics" }, {
		Hint = e(Label, {
			layoutOrder = 1,
			text = "Green = unlocked. Role titles (everyone, admin, moderator) are not listed.",
			wrapped = true,
		}),
		TitlesLabel = e(Label, { layoutOrder = 2, text = "Titles" }),
		Titles = wrapRow(chips("title", Titles.list), 24, 3),
		StylesLabel = e(Label, { layoutOrder = 4, text = "Name styles" }),
		Styles = wrapRow(chips("nameStyle", NameStyles.list), 24, 5),
	})
end

local function DataEditorPage()
	local userRef = React.useRef(nil)
	local cashRef = React.useRef(nil)
	local snapshot, setSnapshot = React.useState(nil)
	local pending, setPending = React.useState(false)
	local selectedUid, setSelectedUid = React.useState(nil)
	local query, setQuery = React.useState("")

	local function request(action: string, payload)
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin(action, payload)
			setPending(false)
			if result.ok and result.data then
				setSnapshot(result.data)
				if action ~= "dataLoad" then
					Notifications.push("[admin] saved", Theme.colors.cash)
				end
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local function load(userId: number?)
		if not userId then
			Notifications.push("Enter a user id", Theme.colors.bad)
			return
		end
		setSelectedUid(nil)
		request("dataLoad", { userId = userId })
	end

	-- every edit targets the loaded player
	local function run(action: string, payload)
		if not snapshot then
			return
		end
		payload.userId = snapshot.userId
		request(action, payload)
	end

	local readOnly = snapshot ~= nil and snapshot.where == "elsewhere"
	local selected = nil
	local tiles = {}
	local shown = 0
	if snapshot then
		local needle = string.lower(query)
		for index, item in snapshot.inventory do
			if item.uid == selectedUid then
				selected = item
			end
			local info = ItemRegistry.get(item.assetId)
			local name = string.lower(info and info.name or tostring(item.assetId))
			if
				needle ~= ""
				and not string.find(name, needle, 1, true)
				and not string.find(item.uid, needle, 1, true)
			then
				continue
			end
			shown += 1
			tiles[item.uid] = e(ItemTile, {
				id = item.uid,
				layoutOrder = index,
				assetId = item.assetId,
				title = info and info.name or `Unknown {item.assetId}`,
				subtitle = Format.cash(Valuation.value(item)),
				selected = item.uid == selectedUid,
				traits = Traits.of(item),
				tagText = `#{item.serial}`,
				tagColor = Theme.colors.textDim,
				trackerCount = item.tracker and item.tracker.opens or nil,
				equipped = table.find(snapshot.equipped, item.uid) ~= nil,
				onSelect = setSelectedUid,
			})
		end
	end

	local panel = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	}
	if snapshot then
		if selected then
			panel["Editor" .. selected.uid] =
				e(ItemEditor, { item = selected, run = run, pending = pending, readOnly = readOnly })
		end
		panel.Spawn = e(SpawnSection, { run = run, pending = pending, readOnly = readOnly })
		panel.Cosmetics =
			e(CosmeticsSection, { snapshot = snapshot, run = run, pending = pending, readOnly = readOnly })
	else
		panel.Empty = e(Label, {
			layoutOrder = 1,
			text = "Load a player by user id to view and edit their data. Offline players work too.",
			height = 40,
			wrapped = true,
			color = Theme.colors.textDim,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, HEADER),
			BackgroundTransparency = 1,
		}, {
			UserId = e(Box, { inputRef = userRef, size = UDim2.fromOffset(170, HEADER), placeholder = "user id" }),
			Load = e(Button, {
				position = UDim2.fromOffset(176, 0),
				size = UDim2.fromOffset(80, HEADER),
				text = "Load",
				textSize = 14,
				color = Theme.colors.accent,
				disabled = pending,
				onClick = function()
					load(readNumber(userRef))
				end,
			}),
			Me = e(Button, {
				position = UDim2.fromOffset(262, 0),
				size = UDim2.fromOffset(60, HEADER),
				text = "Me",
				textSize = 14,
				disabled = pending,
				onClick = function()
					load(Players.LocalPlayer.UserId)
				end,
			}),
			Reload = e(Button, {
				position = UDim2.fromOffset(328, 0),
				size = UDim2.fromOffset(80, HEADER),
				text = "Reload",
				textSize = 14,
				disabled = pending or snapshot == nil,
				onClick = function()
					load(snapshot and snapshot.userId)
				end,
			}),
			Status = e(Text, {
				Position = UDim2.fromOffset(418, 0),
				Size = UDim2.new(1, -(418 + 260), 1, 0),
				Text = if snapshot
					then `@{snapshot.name} ({snapshot.userId})  ·  {WHERE_TEXT[snapshot.where] or snapshot.where}  ·  {#snapshot.inventory} items`
					elseif pending then "Loading..."
					else "No player loaded",
				TextSize = 12,
				TextColor3 = if readOnly then Theme.colors.bad else Theme.colors.textDim,
			}),
			Cash = e(Box, {
				inputRef = cashRef,
				position = UDim2.new(1, -254, 0, 0),
				size = UDim2.fromOffset(170, HEADER),
				placeholder = if snapshot then `cash {Format.commas(snapshot.cash)}` else "cash",
			}),
			SetCash = e(Button, {
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(78, HEADER),
				text = "Set cash",
				textSize = 13,
				disabled = pending or snapshot == nil or readOnly,
				onClick = function()
					local amount = readNumber(cashRef)
					if amount then
						run("dataSetCash", { amount = amount })
					end
				end,
			}),
		}),
		Search = e(SearchBox, {
			position = UDim2.fromOffset(0, HEADER + 8),
			size = UDim2.new(1, -(PANEL_WIDTH + 12), 0, 28),
			value = query,
			placeholder = if snapshot then `Search {shown} items by name or uid...` else "Search...",
			onChange = setQuery,
		}),
		Items = e(Grid, {
			position = UDim2.fromOffset(0, HEADER + 44),
			size = UDim2.new(1, -(PANEL_WIDTH + 12), 1, -(HEADER + 44)),
			cellSize = UDim2.fromOffset(118, 150),
			cellPadding = UDim2.fromOffset(6, 6),
		}, tiles),
		Panel = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, HEADER + 8),
			Size = UDim2.new(0, PANEL_WIDTH, 1, -(HEADER + 8)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
		}, panel),
	})
end

return DataEditorPage
