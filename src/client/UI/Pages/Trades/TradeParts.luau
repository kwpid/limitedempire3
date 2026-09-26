-- small pieces shared by the trades page and the trade composer: item tiles for trade items, a player headshot,
-- value totals, "time ago" text and the status labels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local ItemTile = require(script.Parent.Parent.Parent.Components.ItemTile)

local e = React.createElement

local TradeParts = {}

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

-- an ItemTile for a trade item. props: item, layoutOrder, selected?, onSelect?(uid)
function TradeParts.Tile(props)
	local item = props.item
	local band = Condition.fromFloat(item.float)
	return e(ItemTile, {
		id = item.uid,
		layoutOrder = props.layoutOrder,
		assetId = item.assetId,
		subtitle = Format.cash(Valuation.value(item)),
		selected = props.selected,
		traits = Traits.of(item),
		tagText = band.name,
		tagColor = band.color,
		trackerCount = item.tracker and item.tracker.opens or nil,
		onSelect = props.onSelect,
	})
end

return TradeParts
