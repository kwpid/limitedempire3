local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Income = require(ReplicatedStorage.Shared.Economy.Income)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local usePlayerState = require(script.Parent.Parent.Hooks.usePlayerState)
local usePlayerAttribute = require(script.Parent.Parent.Hooks.usePlayerAttribute)
local useTextWidth = require(script.Parent.Parent.Hooks.useTextWidth)

local e = React.createElement

local CARD_HEIGHT = 56
local LUCK_HEIGHT = 26
local STRIP_WIDTH = 3
local PAD_X = 14
local AMOUNT_SIZE = 24
local LABEL_SIZE = 12
local LUCK_SIZE = 15

local DISPLAY_FONT = Theme.display(Enum.FontWeight.Medium)

-- props: compact? (phones: sits in the top left instead of the bottom left, clear of the bottom nav)
local function Wallet(props)
	local state = usePlayerState()
	local luck = usePlayerAttribute("Luck")
	local level = usePlayerAttribute("Level")
	-- passive income, shown next to the balance label
	local rateText = `+{Format.short(Income.perMinute(if type(level) == "number" then level else 1))}/MIN`
	local showLuck = type(luck) == "number" and luck ~= 1

	local amountText = Config.Currency.Symbol .. Format.commas(state.cash)
	local luckText = if showLuck then string.upper(string.format("Luck %gx", luck)) else ""
	local amountWidth = useTextWidth(amountText, DISPLAY_FONT, AMOUNT_SIZE)
	local labelWidth = useTextWidth("BALANCE", DISPLAY_FONT, LABEL_SIZE)
		+ 10
		+ useTextWidth(rateText, DISPLAY_FONT, LABEL_SIZE)
	local luckWidth = useTextWidth(luckText, DISPLAY_FONT, LUCK_SIZE)
	local cardWidth = math.max(amountWidth, labelWidth, 90) + PAD_X * 2

	return e("Frame", {
		AnchorPoint = if props.compact then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if props.compact then UDim2.fromOffset(16, 12) else UDim2.new(0, 16, 1, -14),
		Size = UDim2.fromOffset(STRIP_WIDTH + cardWidth, CARD_HEIGHT + LUCK_HEIGHT + 6),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Luck = if showLuck
			then e("Frame", {
				Size = UDim2.fromOffset(luckWidth + 20, LUCK_HEIGHT),
				BackgroundColor3 = Theme.colors.topbar,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.good, Transparency = 0.4 }),
				Label = e(Text, {
					Size = UDim2.fromScale(1, 1),
					Text = luckText,
					TextSize = LUCK_SIZE,
					TextColor3 = Theme.colors.good:Lerp(Color3.new(1, 1, 1), 0.3),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.None,
					display = true,
				}),
			})
			else nil,
		Strip = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(STRIP_WIDTH, CARD_HEIGHT),
			BackgroundColor3 = Theme.colors.cash,
			BorderSizePixel = 0,
		}),
		Card = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, STRIP_WIDTH, 1, 0),
			Size = UDim2.fromOffset(cardWidth, CARD_HEIGHT),
			BackgroundColor3 = Theme.colors.topbar,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
		}, {
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Label = e(Text, {
				Position = UDim2.fromOffset(PAD_X, 8),
				Size = UDim2.new(1, -PAD_X * 2, 0, 14),
				Text = "Balance",
				TextSize = LABEL_SIZE,
				TextColor3 = Theme.colors.textFaint,
				TextTruncate = Enum.TextTruncate.None,
				display = true,
			}),
			Rate = e(Text, {
				Position = UDim2.fromOffset(PAD_X, 8),
				Size = UDim2.new(1, -PAD_X * 2, 0, 14),
				Text = rateText,
				TextSize = LABEL_SIZE,
				TextColor3 = Color3.fromRGB(130, 210, 120),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.None,
				display = true,
			}),
			Amount = e(Text, {
				Position = UDim2.fromOffset(PAD_X, 23),
				Size = UDim2.new(1, -PAD_X * 2, 0, 26),
				Text = amountText,
				TextSize = AMOUNT_SIZE,
				TextColor3 = Theme.colors.cash,
				TextTruncate = Enum.TextTruncate.None,
				display = true,
			}),
		}),
	})
end

return Wallet
