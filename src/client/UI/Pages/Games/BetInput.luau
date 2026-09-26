-- the bet amount for the cash games: a box to type it (accepts "10k", "1.5m", commas) and ½ / 2x / Max buttons.
-- props: value (number), onChange(number), cash, disabled?, position?, size?

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CashGames = require(Shared.Games.CashGames)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)

local e = React.createElement

local HEIGHT = 38
local SUFFIXES = { k = 1e3, m = 1e6, b = 1e9 }

-- "12,500" -> 12500, "10k" -> 10000, "1.5m" -> 1500000, nonsense -> nil
local function parse(text: string): number?
	local clean = string.lower(string.gsub(text, "[,%s]", ""))
	local number, suffix = string.match(clean, "^(%d*%.?%d+)([kmb]?)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	return math.floor(value * (SUFFIXES[suffix] or 1))
end

local function clampBet(value: number, cash: number): number
	return math.clamp(math.floor(value), CashGames.MIN_BET, math.max(CashGames.MIN_BET, math.min(cash, CashGames.MAX_BET)))
end

local function BetInput(props)
	local text, setText = React.useState(tostring(props.value))
	local focused, setFocused = React.useState(false)

	-- show outside changes (½, 2x, Max) unless the player is typing
	React.useEffect(function()
		if not focused then
			setText(Format.commas(props.value))
		end
	end, { props.value, focused } :: { any })

	local function quick(value: number)
		props.onChange(clampBet(value, props.cash))
	end

	return e("Frame", {
		Position = props.position,
		Size = props.size or UDim2.new(1, 0, 0, HEIGHT + 22),
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Size = UDim2.new(1, 0, 0, 16),
			Text = "Bet",
			TextSize = 14,
			TextColor3 = Theme.colors.textDim,
			display = true,
		}),
		Box = e("Frame", {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -174, 0, HEIGHT),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if focused then Theme.colors.strokeLight else Theme.colors.stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Symbol = e(Text, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(0, 24, 1, 0),
				Text = "T$",
				TextSize = 15,
				TextColor3 = Theme.colors.cash,
				display = true,
			}),
			Input = e("TextBox", {
				Position = UDim2.fromOffset(34, 0),
				Size = UDim2.new(1, -42, 1, 0),
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				TextEditable = not props.disabled,
				Text = text,
				PlaceholderText = "Amount",
				PlaceholderColor3 = Theme.colors.textFaint,
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Bold),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				[React.Change.Text] = function(box: TextBox)
					setText(box.Text)
					local value = parse(box.Text)
					if value then
						props.onChange(value)
					end
				end,
				[React.Event.Focused] = function()
					setFocused(true)
				end,
				[React.Event.FocusLost] = function()
					setFocused(false)
					quick(parse(text) or props.value)
				end,
			}),
		}),
		Half = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -118, 0, 22),
			size = UDim2.fromOffset(52, HEIGHT),
			text = "½",
			textSize = 16,
			disabled = props.disabled,
			onClick = function()
				quick(props.value / 2)
			end,
		}),
		Double = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -60, 0, 22),
			size = UDim2.fromOffset(52, HEIGHT),
			text = "2x",
			textSize = 16,
			disabled = props.disabled,
			onClick = function()
				quick(props.value * 2)
			end,
		}),
		Max = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, 22),
			size = UDim2.fromOffset(54, HEIGHT),
			text = "Max",
			textSize = 15,
			disabled = props.disabled,
			onClick = function()
				quick(props.cash)
			end,
		}),
	})
end

return BetInput
