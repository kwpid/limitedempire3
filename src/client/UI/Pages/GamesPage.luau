-- the Games window. with no game picked it shows the game menu (a card per game with a short description and a
-- Play button), otherwise the picked game. the window's back button (App) returns to the menu. the menu scrolls
-- vertically: the first FEATURED games side by side on top, the rest in a grid below.
-- GamesPage.list is the menu, add a game by adding an entry and its page.
-- props: game (id or nil), onSelect(id), inventory, equipped, pinned, onInspect(uid)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local HigherLower = require(Shared.Games.HigherLower)
local CashGames = require(Shared.Games.CashGames)
local TradeUp = require(Shared.Games.TradeUp)
local Upgrader = require(Shared.Games.Upgrader)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local UpgraderPage = require(script.Parent.Games.UpgraderPage)
local CaseBattlesPage = require(script.Parent.Games.CaseBattlesPage)
local TradeUpPage = require(script.Parent.Games.TradeUpPage)
local HigherLowerPage = require(script.Parent.Games.HigherLowerPage)
local CoinflipPage = require(script.Parent.Games.CoinflipPage)
local DicePage = require(script.Parent.Games.DicePage)
local CrashPage = require(script.Parent.Games.CrashPage)
local MinesPage = require(script.Parent.Games.MinesPage)
local Mines = require(Shared.Games.Mines)

local e = React.createElement

local FEATURED = 2
local FEATURED_HEIGHT = 170
local COLUMNS = 3
local CARD_HEIGHT = 236
local CARD_GAP = 12

-- the first FEATURED entries are the featured games, shown as wide cards across the top
local GAMES = {
	{
		id = "casebattles",
		name = "Case Battles",
		color = Color3.fromRGB(235, 90, 70),
		description = "Everyone opens the same cases and the highest total value takes every item. Create a lobby, join one, or play solo against bots.",
		facts = { "2 to 4 players, bots fill empty seats", "Winner takes every item" },
		page = CaseBattlesPage,
	},
	{
		id = "upgrader",
		name = "Upgrader",
		color = Color3.fromRGB(88, 180, 90),
		description = "Put in up to 6 items and aim for something worth more. The bigger the jump, the lower the chance.",
		facts = {
			`Up to {math.floor(Upgrader.MAX_CHANCE * 100)}% chance`,
			`{math.floor(Upgrader.HOUSE_EDGE * 100)}% house edge`,
		},
		page = UpgraderPage,
	},
	{
		id = "tradeup",
		name = "Trade-Up",
		color = Color3.fromRGB(136, 90, 255),
		description = `Turn {TradeUp.COUNT} items of one rarity into 1 item of the next. The result float is the average of yours.`,
		facts = { `{TradeUp.COUNT} items in, 1 out`, "See every result first" },
		page = TradeUpPage,
	},
	{
		id = "hilo",
		name = "Higher or Lower",
		color = Color3.fromRGB(229, 186, 71),
		description = "Know your limiteds? Guess if the next item is worth more or less. Streaks pay more.",
		facts = { `Up to {Format.cash(HigherLower.DAILY_CAP)} a day`, "Skill based" },
		page = HigherLowerPage,
	},
	{
		id = "coinflip",
		name = "Coinflip",
		color = Color3.fromRGB(245, 160, 60),
		description = "Heads or tails, double or nothing. Bet as much or as little cash as you like.",
		facts = { `Pays {string.format("%.2f", CashGames.COINFLIP_MULTIPLIER)}x`, "50/50 odds" },
		page = CoinflipPage,
	},
	{
		id = "dice",
		name = "Dice",
		color = Color3.fromRGB(80, 170, 240),
		description = "Pick your odds and roll under them. Safe bets pay a little, long shots pay a lot.",
		facts = {
			`{CashGames.MIN_CHANCE}% to {CashGames.MAX_CHANCE}% chance`,
			`Up to {math.floor(CashGames.diceMultiplier(CashGames.MIN_CHANCE))}x`,
		},
		page = DicePage,
	},
	{
		id = "crash",
		name = "Crash",
		color = Color3.fromRGB(235, 80, 110),
		description = "Watch the multiplier climb and cash out before it crashes. Wait longer, win bigger.",
		facts = { "Cash out any time", "Set an auto cash out" },
		page = CrashPage,
	},
	{
		id = "mines",
		name = "Mines",
		color = Color3.fromRGB(90, 200, 140),
		description = "Find gems, dodge mines. Every safe tile raises your payout, one mine loses it all.",
		facts = { `{Mines.MIN_MINES} to {Mines.MAX_MINES} mines`, "Cash out any time" },
		page = MinesPage,
	},
}

local function Card(props)
	local entry = props.game
	local hovered, setHovered = React.useState(false)

	local facts = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, fact in entry.facts do
		facts["Fact" .. index] = e(Text, {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 16),
			Text = "•  " .. fact,
			TextSize = 13,
			TextColor3 = Theme.colors.text,
		})
	end

	local featured = props.featured == true
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			Sfx.play("tab")
			props.onSelect(entry.id)
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", {
			Color = if hovered then entry.color else Theme.colors.stroke,
			Thickness = if hovered then 2 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Glow = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = entry.color,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, if hovered then 0.7 else 0.82),
					NumberSequenceKeypoint.new(0.6, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
		Accent = e("Frame", {
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = entry.color,
			BorderSizePixel = 0,
		}),
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 22),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
				PaddingBottom = UDim.new(0, 18),
			}),
			Name = e(Text, {
				Size = UDim2.new(1, 0, 0, 34),
				Text = entry.name,
				TextSize = 32,
				TextColor3 = entry.color,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Description = e(Text, {
				Position = UDim2.fromOffset(0, 42),
				Size = if featured then UDim2.new(1, 0, 0, 50) else UDim2.new(1, 0, 0, 56),
				Text = entry.description,
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			-- featured cards: facts bottom left, beside the Play button
			Facts = e("Frame", {
				AnchorPoint = if featured then Vector2.new(0, 1) else Vector2.zero,
				Position = if featured then UDim2.fromScale(0, 1) else UDim2.fromOffset(0, 104),
				Size = if featured then UDim2.new(1, -196, 0, 40) else UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
			}, facts),
			Play = e(Button, {
				anchorPoint = if featured then Vector2.new(1, 1) else Vector2.new(0, 1),
				position = if featured then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1),
				size = if featured then UDim2.fromOffset(180, 48) else UDim2.new(1, 0, 0, 44),
				text = "Play",
				textSize = 20,
				color = entry.color:Lerp(Theme.colors.panel, 0.25),
				sound = "tab",
				onClick = function()
					props.onSelect(entry.id)
				end,
			}),
		}),
	})
end

local function GamesPage(props)
	local selected = nil
	for _, entry in GAMES do
		if entry.id == props.game then
			selected = entry
		end
	end

	if selected then
		return e(selected.page, {
			cash = props.cash,
			inventory = props.inventory,
			equipped = props.equipped,
			pinned = props.pinned,
			onInspect = props.onInspect,
		})
	end

	local featured = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local cards = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / COLUMNS, -CARD_GAP * (COLUMNS - 1) / COLUMNS, 0, CARD_HEIGHT),
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in GAMES do
		if index <= FEATURED then
			featured[entry.id] = e("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1 / FEATURED, -CARD_GAP * (FEATURED - 1) / FEATURED, 1, 0),
				BackgroundTransparency = 1,
			}, {
				Card = e(Card, { game = entry, featured = true, onSelect = props.onSelect }),
			})
		else
			cards[entry.id] = e(Card, { layoutOrder = index, game = entry, onSelect = props.onSelect })
		end
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, {
		Layout = e("UIListLayout", { Padding = UDim.new(0, CARD_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
		Caption = e(Text, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Text = "Pick a game. Item games never use equipped or pinned items.",
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
		}),
		Featured = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, FEATURED_HEIGHT),
			BackgroundTransparency = 1,
		}, featured),
		Cards = e("Frame", {
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, cards),
	})
end

return {
	list = GAMES,
	component = GamesPage,
}
