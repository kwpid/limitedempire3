-- the Titles and Name Styles tabs of the inventory: every title (or name style) the player owns as a card with a
-- live preview. click a card to equip it. titles and styles they don't own are not shown at all.
-- props: kind ("title" | "nameStyle")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)
local Titles = require(ReplicatedStorage.Shared.Titles)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Grid = require(script.Parent.Parent.Components.Grid)
local Checkmark = require(script.Parent.Parent.Components.Checkmark)
local TitleText = require(script.Parent.Parent.Components.TitleText)
local NameLabel = require(script.Parent.Parent.Components.NameLabel)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local usePlayerAttribute = require(script.Parent.Parent.Hooks.usePlayerAttribute)

local e = React.createElement

local KINDS = {
	title = { list = Titles.list, attribute = "Title", ownedAttribute = "OwnedTitles", noun = "title" },
	nameStyle = {
		list = NameStyles.list,
		attribute = "NameStyle",
		ownedAttribute = "OwnedNameStyles",
		noun = "name style",
	},
}

local function decode(raw: any): { [string]: boolean }
	local set = {}
	if type(raw) ~= "string" then
		return set
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(list) == "table" then
		for _, id in list do
			set[id] = true
		end
	end
	return set
end

local function Card(props)
	local hovered, setHovered = React.useState(false)
	local entry = props.entry
	local owned = props.owned
	local equipped = props.equipped

	local preview
	if props.kind == "title" then
		preview = e(TitleText, {
			titleId = entry.id,
			showNone = true,
			textSize = 22,
			size = UDim2.new(1, -20, 0, 30),
			position = UDim2.new(0.5, 0, 0, 20),
			anchorPoint = Vector2.new(0.5, 0),
		})
	else
		preview = e(NameLabel, {
			text = Players.LocalPlayer.DisplayName,
			styleId = entry.id,
			textSize = 24,
			size = UDim2.new(1, -20, 0, 30),
			position = UDim2.new(0.5, 0, 0, 20),
			anchorPoint = Vector2.new(0.5, 0),
		})
	end

	local status, statusColor
	if equipped then
		status, statusColor = "Equipped", Theme.colors.good
	elseif owned then
		status, statusColor = "Click to equip", Theme.colors.textDim
	else
		status = if entry.level
			then `Locked  ·  reach career level {entry.level}`
			elseif props.kind == "nameStyle" then "Locked  ·  exclusive, from codes and events"
			else "Locked  ·  earned through quests and events"
		statusColor = Theme.colors.textFaint
	end

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Active = owned,
		[React.Event.Activated] = function()
			if owned and not equipped then
				Sfx.play("equip")
				props.onEquip(entry.id)
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Color = if equipped
				then Theme.colors.good
				elseif hovered and owned then Theme.colors.strokeLight
				else Theme.colors.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Dim = if owned
			then nil
			else e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.colors.backdrop,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),
		Preview = preview,
		Description = e(Text, {
			Position = UDim2.new(0, 12, 1, -44),
			Size = UDim2.new(1, -24, 0, 16),
			Text = entry.description or "",
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Status = e(Text, {
			Position = UDim2.new(0, 12, 1, -24),
			Size = UDim2.new(1, -24, 0, 14),
			Text = status,
			TextSize = 11,
			TextColor3 = statusColor,
			TextXAlignment = Enum.TextXAlignment.Center,
			weight = Enum.FontWeight.Bold,
			ZIndex = 4,
		}),
		Check = equipped and e(Checkmark, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, 8),
			size = 16,
			zIndex = 4,
		}),
	})
end

local function CosmeticsPage(props)
	local kind = KINDS[props.kind]
	local equippedId = usePlayerAttribute(kind.attribute)
	local owned = decode(usePlayerAttribute(kind.ownedAttribute))
	local pending, setPending = React.useState(false)

	local function equip(id: string)
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.setCosmetic(props.kind, id)
			setPending(false)
			if not result.ok then
				Sfx.play("error")
				Notifications.push(result.err or "Could not equip that", Theme.colors.bad)
			end
		end)
	end

	local ownedCount = 0
	local cards = {}
	for index, entry in kind.list do
		if owned[entry.id] then
			ownedCount += 1
			cards[entry.id] = e(Card, {
				layoutOrder = index,
				kind = props.kind,
				entry = entry,
				owned = true,
				equipped = equippedId == entry.id,
				onEquip = equip,
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Caption = e(Text, {
			Size = UDim2.new(1, 0, 0, 20),
			Text = `{ownedCount} {if ownedCount == 1 then kind.noun else kind.noun .. "s"}  ·  more are earned through quests and events`,
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
		}),
		Cards = e(Grid, {
			position = UDim2.fromOffset(0, 28),
			size = UDim2.new(1, 0, 1, -28),
			cellSize = UDim2.fromOffset(230, 110),
			cellPadding = UDim2.fromOffset(8, 8),
		}, cards),
	})
end

return React.memo(CosmeticsPage)
