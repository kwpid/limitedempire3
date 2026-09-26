-- small pieces shared by the trades page and the trade composer: item tiles for trade items, a player headshot,
-- value totals, "time ago" text and the status labels.
-- hover cards: wrap a page in TradeParts.HoverLayer { onInspect(item) } and every TradeParts.Tile in it (and anything
-- using TradeParts.useHover) shows the item's full stats in a card beside it while hovered (or tapped), with an
-- Inspect button, so players can check floats, serials and traits before trading instead of trusting a name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local ItemTile = require(script.Parent.Parent.Parent.Components.ItemTile)
local ItemDetails = require(script.Parent.Parent.Parent.Components.ItemDetails)
local Button = require(script.Parent.Parent.Parent.Components.Button)

local e = React.createElement

local TradeParts = {}

local CARD_WIDTH = 270
local CARD_GAP = 8
local CLOSE_DELAY = 0.15
-- a frame of this size lets the layer turn absolute (scaled) positions back into its own units
local UNIT = 100

local HoverContext = React.createContext(nil)

-- the hover api for custom item buttons: { open(item, gui), close(), keep(), hide() }, nil outside a HoverLayer
function TradeParts.useHover()
	return React.useContext(HoverContext)
end

local function Card(props)
	local hover = props.hover
	return e("Frame", {
		AnchorPoint = Vector2.new(if props.right then 0 else 1, if props.below then 1 else 0),
		Position = UDim2.fromOffset(props.x, props.y),
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.colors.window,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 20,
		[React.Event.MouseEnter] = hover.keep,
		[React.Event.MouseLeave] = hover.close,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.strokeLight }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Details = e(ItemDetails, { item = props.item, thumbnailSize = 70, layoutOrder = 1 }),
		Inspect = e(Button, {
			layoutOrder = 2,
			size = UDim2.new(1, 0, 0, 32),
			text = "Inspect",
			textSize = 15,
			color = Theme.colors.accent,
			onClick = function()
				hover.hide()
				props.onInspect(props.item)
			end,
		}),
	})
end

-- fills its parent, draws children, and shows the hover card over them. props: onInspect(item), children
function TradeParts.HoverLayer(props)
	local card, setCard = React.useState(nil)
	local rootRef = React.useRef(nil)
	local unitRef = React.useRef(nil)
	local closeThread = React.useRef(nil)

	local hover = React.useMemo(function()
		local function keep()
			if closeThread.current then
				pcall(task.cancel, closeThread.current)
				closeThread.current = nil
			end
		end
		return {
			keep = keep,
			open = function(item, gui: GuiObject?)
				keep()
				local root, unit = rootRef.current, unitRef.current
				if not (root and unit and gui) or unit.AbsoluteSize.X <= 0 then
					return
				end
				local scale = unit.AbsoluteSize.X / UNIT
				local at = (gui.AbsolutePosition - root.AbsolutePosition) / scale
				local size = gui.AbsoluteSize / scale
				local rootSize = root.AbsoluteSize / scale
				-- beside the item, on the right unless there's no room, lined up with its top (or its bottom in the
				-- lower half so the card grows upward)
				local right = at.X + size.X + CARD_GAP + CARD_WIDTH <= rootSize.X
				local below = at.Y + size.Y / 2 > rootSize.Y / 2
				setCard({
					item = item,
					right = right,
					below = below,
					x = if right then at.X + size.X + CARD_GAP else at.X - CARD_GAP,
					y = if below then at.Y + size.Y else at.Y,
				})
			end,
			close = function()
				keep()
				closeThread.current = task.delay(CLOSE_DELAY, function()
					closeThread.current = nil
					setCard(nil)
				end)
			end,
			hide = function()
				keep()
				setCard(nil)
			end,
		}
	end, {})

	React.useEffect(function()
		return hover.keep
	end, {})

	return e(HoverContext.Provider, { value = hover }, {
		Root = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ref = rootRef,
		}, {
			Unit = e("Frame", {
				Size = UDim2.fromOffset(UNIT, UNIT),
				BackgroundTransparency = 1,
				ref = unitRef,
			}),
			Content = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, props.children),
			Card = card and e(Card, {
				item = card.item,
				right = card.right,
				below = card.below,
				x = card.x,
				y = card.y,
				hover = hover,
				onInspect = props.onInspect,
			}) or nil,
		}),
	})
end

TradeParts.STATUS = {
	pending = { text = "Pending", color = Theme.colors.marker },
	processing = { text = "Processing", color = Color3.fromRGB(120, 190, 255) },
	completed = { text = "Completed", color = Color3.fromRGB(130, 210, 120) },
	declined = { text = "Declined", color = Theme.colors.textDim },
	countered = { text = "Countered", color = Theme.colors.textDim },
	cancelled = { text = "Cancelled", color = Theme.colors.textDim },
	inactive = { text = "Inactive", color = Theme.colors.textDim },
}

function TradeParts.total(items): number
	local sum = 0
	for _, item in items do
		sum += Valuation.value(item)
	end
	return sum
end

function TradeParts.ago(timestamp: number): string
	local seconds = math.max(0, os.time() - timestamp)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60)}m ago`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)}h ago`
	end
	return `{math.floor(seconds / 86400)}d ago`
end

function TradeParts.headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

-- the trade's tab: inbound / outbound while it is open, then completed or inactive
function TradeParts.tabOf(trade): string
	if trade.status == "completed" then
		return "completed"
	elseif trade.status == "pending" or trade.status == "processing" then
		return trade.direction
	end
	return "inactive"
end

function TradeParts.Avatar(props)
	return e("ImageLabel", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundColor3 = Theme.colors.inset,
		Image = TradeParts.headshot(props.userId),
		ZIndex = props.zIndex,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", { Color = props.color or Theme.colors.stroke }),
	})
end

-- an ItemTile for a trade item that shows its hover card. props: item, layoutOrder, selected?, onSelect?(uid)
-- (without onSelect, clicking or tapping the tile shows the card, for touch screens)
function TradeParts.Tile(props)
	local item = props.item
	local hover = TradeParts.useHover()
	local frameRef = React.useRef(nil)
	local band = Condition.fromFloat(item.float)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ref = frameRef,
		[React.Event.MouseEnter] = function(rbx)
			if hover then
				hover.open(item, rbx)
			end
		end,
		[React.Event.MouseLeave] = function()
			if hover then
				hover.close()
			end
		end,
	}, {
		Tile = e(ItemTile, {
			id = item.uid,
			size = UDim2.fromScale(1, 1),
			assetId = item.assetId,
			subtitle = Format.cash(Valuation.value(item)),
			selected = props.selected,
			traits = Traits.of(item),
			tagText = band.name,
			tagColor = band.color,
			trackerCount = item.tracker and item.tracker.opens or nil,
			onSelect = props.onSelect or (hover and function()
				hover.open(item, frameRef.current)
			end),
		}),
	})
end

return TradeParts
