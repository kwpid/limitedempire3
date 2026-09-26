-- shared layout for the cash games (Coinflip, Dice): a controls panel on the left, the game on the right, a row of
-- recent results under it, and a payout line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local CashGameParts = {}

CashGameParts.PANEL_WIDTH = 340
CashGameParts.HISTORY = 14
CashGameParts.WIN = Color3.fromRGB(130, 210, 120)
CashGameParts.LOSE = Color3.fromRGB(220, 110, 90)

function CashGameParts.fail(message: string?)
	Sfx.play("error")
	Notifications.push(message or "Something went wrong", Theme.colors.bad)
end

-- toast and sound for a finished bet
function CashGameParts.announce(won: boolean, bet: number, payout: number)
	if won then
		Sfx.play("revealRare", 1.1)
		Notifications.push(`Won {Format.cash(payout)}  (+{Format.cash(payout - bet)})`, CashGameParts.WIN)
	else
		Sfx.play("error")
	end
end

-- keeps the newest results first, at most HISTORY of them
function CashGameParts.pushHistory(list, entry)
	local nextList = { entry }
	for index = 1, math.min(#list, CashGameParts.HISTORY - 1) do
		table.insert(nextList, list[index])
	end
	return nextList
end

-- the left side. props: children (laid out top to bottom)
function CashGameParts.Panel(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("ScrollingFrame", {
		Size = UDim2.new(0, CashGameParts.PANEL_WIDTH, 1, 0),
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, children)
end

-- "label ........ value" line. props: layoutOrder, label, value, color?
function CashGameParts.Line(props)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Size = UDim2.fromScale(0.5, 1),
			Text = props.label,
			TextSize = 14,
			TextColor3 = Theme.colors.textDim,
		}),
		Value = e(Text, {
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = props.value,
			TextSize = 15,
			TextColor3 = props.color or Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
			weight = Enum.FontWeight.Bold,
		}),
	})
end

-- recent results as small chips, newest first. props: entries ({ text, won }), position, size
function CashGameParts.History(props)
	local chips = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in props.entries do
		local color = if entry.won then CashGameParts.WIN else CashGameParts.LOSE
		chips["Chip" .. index] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = color:Lerp(Theme.colors.panel, 0.75),
			BackgroundTransparency = if index == 1 then 0 else 0.3,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = color, Transparency = if index == 1 then 0 else 0.6 }),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Label = e(Text, {
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = entry.text,
				TextSize = 14,
				TextColor3 = color,
				TextTruncate = Enum.TextTruncate.None,
				weight = Enum.FontWeight.Bold,
			}),
		})
	end
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, {
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 16),
			Text = if #props.entries > 0 then "Recent" else "",
			TextSize = 13,
			TextColor3 = Theme.colors.textFaint,
			display = true,
		}),
		Chips = e("Frame", {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
		}, chips),
	})
end

return CashGameParts
