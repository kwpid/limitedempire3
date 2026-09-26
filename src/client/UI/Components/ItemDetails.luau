local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local SeriesRegistry = require(Shared.Series.SeriesRegistry)
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Serial = require(Shared.Modifiers.Serial)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local TraitText = require(script.Parent.TraitText)
local TrackerBadge = require(script.Parent.TrackerBadge)
local TierGradient = require(script.Parent.TierGradient)
local useSetting = require(script.Parent.Parent.Hooks.useSetting)

local e = React.createElement

local function Row(props)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	}, {
		Line = e("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.colors.stroke,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
		}),
		Label = e(Text, {
			Size = UDim2.fromScale(0.4, 1),
			Text = props.label,
			TextSize = 12,
			TextColor3 = Theme.colors.textFaint,
		}),
		Value = e(TraitText, {
			trait = props.trait,
			Position = UDim2.fromScale(0.4, 0),
			Size = UDim2.fromScale(0.6, 1),
			Text = props.value,
			TextSize = 12,
			TextColor3 = props.color or Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function multiplierText(mult: number): string
	if mult == 1 then
		return ""
	end
	return string.format("  x%.2f", mult)
end

local function ownerText(owner): string
	if not owner then
		return "Unknown"
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer and owner.userId == localPlayer.UserId then
		return `@{owner.name} (you)`
	end
	return "@" .. owner.name
end

local function ItemDetails(props)
	local item = props.item
	local info = ItemRegistry.get(item.assetId)
	local tier = ItemRegistry.tier(item.assetId)
	local band = Condition.fromFloat(item.float)
	local advanced = useSetting("advancedStats")
	local traitIds = Traits.of(item)
	local trait = Traits.get(traitIds[1])
	local stacked = Traits.get(traitIds[2])
	local breakdown = Valuation.breakdown(item)
	local serialLabel = Serial.label(item.serial)
	local thumbSize = props.thumbnailSize or 150

	return e("Frame", {
		Size = props.size or UDim2.fromScale(1, 0),
		AutomaticSize = props.size and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		Position = props.position,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Showcase = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, thumbSize + 16),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Fade = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = tier.color,
				BorderSizePixel = 0,
			}, {
				Gradient = e("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 1),
						NumberSequenceKeypoint.new(1, 0.75),
					}),
				}),
			}),
			Thumbnail = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(thumbSize, thumbSize),
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(item.assetId, 420),
			}),
			Bar = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = tier.color,
				BorderSizePixel = 0,
			}, {
				Shimmer = e(TierGradient, { tier = tier }),
			}),
			Tracker = item.tracker and e(TrackerBadge, {
				count = item.tracker.opens,
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.new(0, 6, 1, -8),
				zIndex = 2,
			}),
		}),
		Spacer = e("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(0, 6), BackgroundTransparency = 1 }),
		Name = e(TraitText, {
			trait = traitIds[1],
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 24),
			Text = Traits.fullName(traitIds, info and info.name or "Unknown"),
			TextSize = 20,
			TextColor3 = trait and trait.uiColor or Theme.colors.text,
			display = true,
		}),
		Tier = e(Text, {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 16),
			Text = tier.name .. " Limited" .. (info and info.year > 0 and `, {info.year}` or ""),
			TextSize = 12,
			TextColor3 = tier.color,
		}, {
			Shimmer = e(TierGradient, { tier = tier }),
		}),
		Value = e(Text, {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 30),
			Text = Format.cash(breakdown.total),
			TextSize = 24,
			TextColor3 = Theme.colors.cash,
			display = true,
		}),
		Base = e(Row, {
			layoutOrder = 6,
			label = "Base value",
			value = Format.cash(breakdown.base),
		}),
		Condition = e(Row, {
			layoutOrder = 7,
			label = "Condition",
			value = band.name .. multiplierText(breakdown.condition),
			color = band.color,
		}),
		Float = e(Row, {
			layoutOrder = 8,
			label = "Float",
			value = Format.float(item.float),
		}),
		Serial = e(Row, {
			layoutOrder = 9,
			label = "Serial",
			value = Format.serial(item.serial) .. (serialLabel and `  {serialLabel}` or "") .. multiplierText(breakdown.serial),
			color = serialLabel and Theme.colors.cash or nil,
		}),
		Trait = e(Row, {
			layoutOrder = 10,
			label = "Trait",
			trait = traitIds[1],
			value = trait and (trait.name .. multiplierText(trait.multiplier)) or "None",
			color = trait and trait.uiColor or Theme.colors.textFaint,
		}),
		Stacked = stacked and e(Row, {
			layoutOrder = 11,
			label = "Stacked trait",
			trait = stacked.id,
			value = string.format("%s  +x%.2f", stacked.name, Traits.stackBonus(stacked.id)),
			color = stacked.uiColor,
		}),
		Tracker = item.tracker and e(Row, {
			layoutOrder = 12,
			label = "Stat Tracker",
			value = `{Format.commas(item.tracker.opens)} opened` .. multiplierText(breakdown.tracker),
			color = Theme.colors.tracker,
		}),
		Series = e(Row, {
			layoutOrder = 13,
			label = "Series",
			value = SeriesRegistry.name(CaseRegistry.itemSeries(item)),
		}),
		Owner = e(Row, {
			layoutOrder = 14,
			label = "OG Owner",
			value = ownerText(item.originalOwner),
			color = if item.originalOwner then nil else Theme.colors.textFaint,
		}),
		Odds = advanced and e(Row, {
			layoutOrder = 15,
			label = "Drop chance",
			value = (function()
				local chance = CaseRegistry.chanceOf(item.caseId, item.assetId)
				local case = item.caseId and CaseRegistry.get(item.caseId)
				return if chance and case then `{Format.odds(chance)} ({case.name})` else "Unknown"
			end)(),
		}),
		AssetId = advanced and e(Row, {
			layoutOrder = 16,
			label = "Asset ID",
			value = tostring(item.assetId),
		}),
		Unboxed = advanced and e(Row, {
			layoutOrder = 17,
			label = "Unboxed",
			value = os.date("%b %d, %Y  %H:%M", item.obtainedAt),
		}),
	})
end

return ItemDetails
