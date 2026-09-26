local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local NameStyles = require(ReplicatedStorage.Shared.Visuals.NameStyles)
local Seasons = require(ReplicatedStorage.Shared.Progress.Seasons)
local Titles = require(ReplicatedStorage.Shared.Titles)
local Condition = require(ReplicatedStorage.Shared.Modifiers.Condition)
local Tiers = require(ReplicatedStorage.Shared.Items.Tiers)
local Traits = require(ReplicatedStorage.Shared.Modifiers.Traits)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Components.Button)
local Actions = require(script.Parent.Parent.Parent.Controllers.Actions)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local usePlayerAttribute = require(script.Parent.Parent.Hooks.usePlayerAttribute)

local e = React.createElement

local QUICK_AMOUNTS = { 1_000, 10_000, 100_000, 1_000_000, 100_000_000 }
local QUICK_LUCK = { 1, 2, 5, 10, 50, 100, 1000 }
local CONFIRM_WINDOW = 3
local OVERRIDE_COUNTS = { 1, 5, 25, -1 }
local PAGE_HEIGHT = 1120
local QUICK_XP = { 100, 1_000, 10_000, 100_000 }
local QUICK_SP = { 100, 1_000, 10_000, -1_000 }
local SP_MULTIPLIERS = { 0.5, 1, 1.5, 2, 3, 5 }

local function parseAmount(text: string): number?
	local cleaned = text:gsub("[,%s]", ""):lower()
	local number, suffix = cleaned:match("^(-?[%d%.]+)([kmb]?)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9 })[suffix] or 1
	return value * mult
end

local function formatLuck(luck: number?): string
	local value = if type(luck) == "number" then luck else 1
	if value == math.floor(value) then
		return `{Format.commas(value)}x`
	end
	return string.format("%.2fx", value)
end

local function Section(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 22),
			Text = props.title,
			TextSize = 18,
			display = true,
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, children)
end

-- small toggle chip used by the next unbox picker
local function Chip(props)
	return e(Button, {
		layoutOrder = props.layoutOrder,
		size = UDim2.fromOffset(props.width or 84, 28),
		text = props.text,
		textSize = props.textSize or 13,
		color = if props.active then Theme.colors.accent else nil,
		disabled = props.disabled,
		onClick = props.onClick,
	})
end

local function chipRow(children)
	children.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return children
end

local function overrideSummary(raw: any): string
	if type(raw) ~= "string" then
		return "Nothing armed, unboxes roll normally."
	end
	local ok, override = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(override) ~= "table" then
		return "Nothing armed, unboxes roll normally."
	end
	local parts = {}
	if override.traits then
		table.insert(parts, Traits.label(override.traits) or "")
	end
	if override.tier then
		local tier = Tiers.get(override.tier)
		table.insert(parts, tier and tier.name or override.tier)
	end
	if override.condition then
		for _, band in Condition.list do
			if band.id == override.condition then
				table.insert(parts, band.name)
			end
		end
	end
	if override.tracker then
		table.insert(parts, "Stat Tracker")
	end
	local left = if override.remaining == -1 then "until cleared" else `{override.remaining} left`
	return `Armed: {if #parts > 0 then table.concat(parts, ", ") else "normal roll"}  ·  {left}`
end

local function AdminPage(props)
	local inputRef = React.useRef(nil)
	local luckInputRef = React.useRef(nil)
	local pending, setPending = React.useState(false)
	local armed, setArmed = React.useState(nil)
	local luck = usePlayerAttribute("Luck") or 1
	local ownedTitlesRaw = usePlayerAttribute("OwnedTitles")
	local grantSeason, setGrantSeason = React.useState((Seasons.current()))
	local grantRemove, setGrantRemove = React.useState(false)
	local grantUserRef = React.useRef(nil)
	local spMultiplier, setSpMultiplier = React.useState(ReplicatedStorage:GetAttribute("SPMultiplier") or 1)
	local boardAllRanks, setBoardAllRanks = React.useState(ReplicatedStorage:GetAttribute("SPBoardAllRanks") == true)
	React.useEffect(function()
		local connections = {
			ReplicatedStorage:GetAttributeChangedSignal("SPMultiplier"):Connect(function()
				setSpMultiplier(ReplicatedStorage:GetAttribute("SPMultiplier") or 1)
			end),
			ReplicatedStorage:GetAttributeChangedSignal("SPBoardAllRanks"):Connect(function()
				setBoardAllRanks(ReplicatedStorage:GetAttribute("SPBoardAllRanks") == true)
			end),
		}
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})
	local nameStyle = usePlayerAttribute("NameStyle")
	local armedOverride = usePlayerAttribute("AdminOverride")
	local pickTraits, setPickTraits = React.useState({})
	local pickTier, setPickTier = React.useState(nil)
	local pickCondition, setPickCondition = React.useState(nil)
	local pickTracker, setPickTracker = React.useState(false)

	local function sendOverride(count: number)
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin("setOverride", {
				traits = pickTraits,
				tier = pickTier,
				condition = pickCondition,
				tracker = pickTracker,
				count = count,
			})
			setPending(false)
			if not result.ok then
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local traitChips = {}
	for index, trait in Traits.list do
		local active = table.find(pickTraits, trait.id) ~= nil
		traitChips[trait.id] = e(Chip, {
			layoutOrder = index,
			text = trait.name,
			width = 96,
			textSize = 12,
			active = active,
			onClick = function()
				local nextTraits = table.clone(pickTraits)
				local at = table.find(nextTraits, trait.id)
				if at then
					table.remove(nextTraits, at)
				elseif #nextTraits < 2 then
					table.insert(nextTraits, trait.id)
				else
					nextTraits = { nextTraits[2], trait.id }
				end
				setPickTraits(nextTraits)
			end,
		})
	end

	local tierChips = {
		Any = e(Chip, {
			layoutOrder = 0,
			text = "Any",
			width = 64,
			active = pickTier == nil,
			onClick = function()
				setPickTier(nil)
			end,
		}),
	}
	for index, tier in Tiers.list do
		tierChips[tier.id] = e(Chip, {
			layoutOrder = index,
			text = tier.name,
			active = pickTier == tier.id,
			onClick = function()
				setPickTier(tier.id)
			end,
		})
	end

	local conditionChips = {
		Any = e(Chip, {
			layoutOrder = 0,
			text = "Any",
			width = 64,
			active = pickCondition == nil,
			onClick = function()
				setPickCondition(nil)
			end,
		}),
	}
	for index, band in Condition.list do
		conditionChips[band.id] = e(Chip, {
			layoutOrder = index,
			text = band.name,
			active = pickCondition == band.id,
			onClick = function()
				setPickCondition(band.id)
			end,
		})
	end
	conditionChips.Tracker = e(Chip, {
		layoutOrder = 100,
		text = "Stat Tracker",
		width = 120,
		active = pickTracker,
		onClick = function()
			setPickTracker(not pickTracker)
		end,
	})

	local countChips = {}
	for index, count in OVERRIDE_COUNTS do
		countChips["Count" .. index] = e(Chip, {
			layoutOrder = index,
			text = if count == -1 then "Until cleared" else `Next {count}`,
			width = if count == -1 then 120 else 84,
			disabled = pending,
			onClick = function()
				sendOverride(count)
			end,
		})
	end
	countChips.Clear = e(Button, {
		layoutOrder = 10,
		size = UDim2.fromOffset(84, 28),
		text = "Clear",
		textSize = 13,
		color = Theme.colors.bad,
		disabled = pending,
		onClick = function()
			sendOverride(0)
		end,
	})

	local function run(action: string, amount: number?)
		if pending then
			return
		end
		if not amount then
			Notifications.push("Enter a number, like 5000 or 2.5m", Theme.colors.bad)
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin(action, { amount = amount })
			setPending(false)
			if result.ok then
				local shown = if action == "setLuck" then formatLuck(amount) else Format.commas(amount)
				Notifications.push(`[admin] {action} {shown}`, Theme.colors.cash)
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local function readInput(): number?
		local box = inputRef.current
		return box and parseAmount(box.Text)
	end

	local function confirmThen(action: string, message: string)
		if pending then
			return
		end
		if armed ~= action then
			setArmed(action)
			task.delay(CONFIRM_WINDOW, function()
				setArmed(function(current)
					return if current == action then nil else current
				end)
			end)
			return
		end
		setArmed(nil)
		setPending(true)
		task.spawn(function()
			local result = Actions.admin(action, nil)
			setPending(false)
			if result.ok then
				Notifications.push(message, Theme.colors.cash)
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end

	local styleButtons = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 34),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, style in NameStyles.list do
		styleButtons[style.id] = e(Button, {
			layoutOrder = index,
			text = style.name,
			textSize = 15,
			color = if nameStyle == style.id then Theme.colors.accent else nil,
			disabled = pending,
			onClick = function()
				setPending(true)
				task.spawn(function()
					local result = Actions.admin("setNameStyle", { style = style.id })
					setPending(false)
					if not result.ok then
						Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
					end
				end)
			end,
		})
	end

	local luckButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, amount in QUICK_LUCK do
		luckButtons["Luck" .. amount] = e(Button, {
			layoutOrder = index,
			size = UDim2.fromOffset(72, 34),
			text = formatLuck(amount),
			textSize = 15,
			color = if luck == amount then Theme.colors.accent else nil,
			disabled = pending,
			onClick = function()
				run("setLuck", amount)
			end,
		})
	end

	local quickButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, amount in QUICK_AMOUNTS do
		quickButtons["Add" .. amount] = e(Button, {
			layoutOrder = index,
			size = UDim2.fromOffset(92, 34),
			text = "+" .. Format.short(amount),
			textSize = 15,
			disabled = pending,
			onClick = function()
				run("addCash", amount)
			end,
		})
	end

	local function progressRow(order: number, amounts: { number }, action: string, suffix: string)
		local row = {}
		for index, amount in amounts do
			row["Amount" .. index] = e(Chip, {
				layoutOrder = order * 10 + index,
				text = `{if amount > 0 then "+" else ""}{Format.short(amount)} {suffix}`,
				width = 96,
				disabled = pending,
				onClick = function()
					run(action, amount)
				end,
			})
		end
		return row
	end
	local multiplierChips = {}
	for index, amount in SP_MULTIPLIERS do
		multiplierChips["Mult" .. index] = e(Chip, {
			layoutOrder = index,
			text = `{amount}x`,
			width = 64,
			active = spMultiplier == amount,
			disabled = pending,
			onClick = function()
				run("setSpMultiplier", amount)
			end,
		})
	end
	local function setBoard(value: boolean)
		if pending then
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin("setBoardAllRanks", { value = value })
			setPending(false)
			if not result.ok then
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end
	local boardChips = {
		Legends = e(Chip, {
			layoutOrder = 1,
			text = "Legends only",
			width = 120,
			active = not boardAllRanks,
			disabled = pending,
			onClick = function()
				setBoard(false)
			end,
		}),
		All = e(Chip, {
			layoutOrder = 2,
			text = "All ranks (testing)",
			width = 150,
			active = boardAllRanks,
			disabled = pending,
			onClick = function()
				setBoard(true)
			end,
		}),
	}
	multiplierChips.Reroll = e(Chip, {
		layoutOrder = 100,
		text = "Reroll my quests",
		width = 140,
		disabled = pending,
		onClick = function()
			confirmThen("resetQuests", "[admin] quests rerolled")
		end,
	})

	-- grant title: any season title, to you (and equipped) or to a user id
	local ownedTitles = {}
	do
		local ok, list = pcall(HttpService.JSONDecode, HttpService, ownedTitlesRaw or "[]")
		for _, id in if ok and type(list) == "table" then list else {} do
			ownedTitles[id] = true
		end
	end
	local function grantTitle(titleId: string)
		if pending then
			return
		end
		local box = grantUserRef.current
		local text = box and box.Text:gsub("%s", "") or ""
		local userId = tonumber(text)
		if text ~= "" and not userId then
			Notifications.push("User id must be a number (leave it blank for you)", Theme.colors.bad)
			return
		end
		setPending(true)
		task.spawn(function()
			local result = Actions.admin("grantTitle", { titleId = titleId, userId = userId, remove = grantRemove })
			setPending(false)
			if result.ok then
				local title = Titles.get(titleId)
				local verb = if grantRemove then "removed" else "granted"
				Notifications.push(`[admin] {verb} {title and title.name or titleId}`, Theme.colors.cash)
			else
				Notifications.push(result.err or "Admin action failed", Theme.colors.bad)
			end
		end)
	end
	local seasonChips = {}
	for seasonId = 0, Seasons.current() + 5 do
		seasonChips["S" .. seasonId] = e(Chip, {
			layoutOrder = seasonId,
			text = `S{seasonId}`,
			width = 48,
			active = grantSeason == seasonId,
			onClick = function()
				setGrantSeason(seasonId)
			end,
		})
	end
	local modeChips = {
		Grant = e(Chip, {
			layoutOrder = 1,
			text = "Grant",
			width = 70,
			active = not grantRemove,
			onClick = function()
				setGrantRemove(false)
			end,
		}),
		Remove = e(Chip, {
			layoutOrder = 2,
			text = "Remove",
			width = 70,
			active = grantRemove,
			onClick = function()
				setGrantRemove(true)
			end,
		}),
	}
	local titleChips = {}
	for index, title in Titles.season(grantSeason) do
		titleChips[title.id] = e(Chip, {
			layoutOrder = index,
			text = title.name,
			width = 132,
			textSize = 12,
			active = ownedTitles[title.id] == true,
			disabled = pending,
			onClick = function()
				grantTitle(title.id)
			end,
		})
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, PAGE_HEIGHT),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, {
		Progress = e(Section, {
			title = "Progress & seasons",
			position = UDim2.fromOffset(0, 680),
			size = UDim2.new(1, -10, 0, 210),
		}, {
			Status = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Season Point multiplier: {spMultiplier}x (server wide, resets when the server closes)`,
				TextSize = 13,
				TextColor3 = if spMultiplier ~= 1 then Theme.colors.cash else Theme.colors.textDim,
			}),
			MultLabel = e(Text, {
				Position = UDim2.fromOffset(0, 54),
				Size = UDim2.fromOffset(90, 28),
				Text = "SP multiplier",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Mult = e("Frame", {
				Position = UDim2.fromOffset(100, 54),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(multiplierChips)),
			XpLabel = e(Text, {
				Position = UDim2.fromOffset(0, 88),
				Size = UDim2.fromOffset(90, 28),
				Text = "Career XP",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Xp = e("Frame", {
				Position = UDim2.fromOffset(100, 88),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(progressRow(1, QUICK_XP, "addXp", "XP"))),
			SpLabel = e(Text, {
				Position = UDim2.fromOffset(0, 122),
				Size = UDim2.fromOffset(90, 28),
				Text = "Season Points",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Sp = e("Frame", {
				Position = UDim2.fromOffset(100, 122),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(progressRow(2, QUICK_SP, "addSp", "SP"))),
			BoardLabel = e(Text, {
				Position = UDim2.fromOffset(0, 156),
				Size = UDim2.fromOffset(90, 28),
				Text = "SP top 100",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Board = e("Frame", {
				Position = UDim2.fromOffset(100, 156),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(boardChips)),
		}),
		GrantTitle = e(Section, {
			title = "Grant title",
			position = UDim2.fromOffset(0, 904),
			size = UDim2.new(1, -10, 0, 200),
		}, {
			PlayerLabel = e(Text, {
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.fromOffset(90, 28),
				Text = "Player",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			PlayerBox = e("TextBox", {
				ref = grantUserRef,
				Position = UDim2.fromOffset(100, 30),
				Size = UDim2.fromOffset(200, 28),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "user id (blank = you)",
				PlaceholderColor3 = Theme.colors.textFaint,
				Text = "",
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Medium),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
			}),
			Mode = e("Frame", {
				Position = UDim2.fromOffset(310, 30),
				Size = UDim2.fromOffset(150, 28),
				BackgroundTransparency = 1,
			}, chipRow(modeChips)),
			SeasonLabel = e(Text, {
				Position = UDim2.fromOffset(0, 64),
				Size = UDim2.fromOffset(90, 28),
				Text = "Season",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Seasons = e("Frame", {
				Position = UDim2.fromOffset(100, 64),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(seasonChips)),
			TitlesLabel = e(Text, {
				Position = UDim2.fromOffset(0, 98),
				Size = UDim2.fromOffset(90, 28),
				Text = "Titles",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Titles = e("Frame", {
				Position = UDim2.fromOffset(100, 98),
				Size = UDim2.new(1, -100, 0, 64),
				BackgroundTransparency = 1,
			}, chipRow(titleChips)),
		}),
		NextUnbox = e(Section, {
			title = "Next unbox (testing)",
			position = UDim2.fromOffset(0, 404),
			size = UDim2.new(1, -10, 0, 262),
		}, {
			Status = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = overrideSummary(armedOverride),
				TextSize = 13,
				TextColor3 = if armedOverride then Theme.colors.cash else Theme.colors.textDim,
			}),
			TraitsLabel = e(Text, {
				Position = UDim2.fromOffset(0, 54),
				Size = UDim2.fromOffset(90, 28),
				Text = "Traits (2 max)",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Traits = e("Frame", {
				Position = UDim2.fromOffset(100, 54),
				Size = UDim2.new(1, -100, 0, 60),
				BackgroundTransparency = 1,
			}, chipRow(traitChips)),
			TierLabel = e(Text, {
				Position = UDim2.fromOffset(0, 124),
				Size = UDim2.fromOffset(90, 28),
				Text = "Rarity",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Tiers = e("Frame", {
				Position = UDim2.fromOffset(100, 124),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(tierChips)),
			ConditionLabel = e(Text, {
				Position = UDim2.fromOffset(0, 158),
				Size = UDim2.fromOffset(90, 28),
				Text = "Condition",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Conditions = e("Frame", {
				Position = UDim2.fromOffset(100, 158),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(conditionChips)),
			ApplyLabel = e(Text, {
				Position = UDim2.fromOffset(0, 202),
				Size = UDim2.fromOffset(90, 28),
				Text = "Apply to",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
			}),
			Apply = e("Frame", {
				Position = UDim2.fromOffset(100, 202),
				Size = UDim2.new(1, -100, 0, 28),
				BackgroundTransparency = 1,
			}, chipRow(countChips)),
		}),
		Cash = e(Section, {
			title = "Cash",
			size = UDim2.new(0, 560, 0, 190),
		}, {
			Balance = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Current balance: {Config.Currency.Symbol}{Format.commas(props.cash)}`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Quick = e("Frame", {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, quickButtons),
			Input = e("TextBox", {
				ref = inputRef,
				Position = UDim2.fromOffset(0, 104),
				Size = UDim2.fromOffset(200, 36),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Amount (5000, 2.5m, 1b)",
				PlaceholderColor3 = Theme.colors.textFaint,
				Text = "",
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Medium),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
			}),
			Add = e(Button, {
				position = UDim2.fromOffset(210, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Add",
				color = Theme.colors.good,
				disabled = pending,
				onClick = function()
					run("addCash", readInput())
				end,
			}),
			Set = e(Button, {
				position = UDim2.fromOffset(312, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Set",
				color = Theme.colors.accent,
				disabled = pending,
				onClick = function()
					run("setCash", readInput())
				end,
			}),
			Reset = e(Button, {
				position = UDim2.fromOffset(414, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Zero",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					run("setCash", 0)
				end,
			}),
		}),
		Luck = e(Section, {
			title = "Luck",
			position = UDim2.fromOffset(0, 202),
			size = UDim2.new(0, 560, 0, 190),
		}, {
			Current = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Current luck: {formatLuck(luck)}. Boosts expensive drops, trait chances and float.`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Quick = e("Frame", {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, luckButtons),
			Input = e("TextBox", {
				ref = luckInputRef,
				Position = UDim2.fromOffset(0, 104),
				Size = UDim2.fromOffset(200, 36),
				BackgroundColor3 = Theme.colors.panel,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Luck (2, 7.5, 250)",
				PlaceholderColor3 = Theme.colors.textFaint,
				Text = "",
				TextColor3 = Theme.colors.text,
				FontFace = Theme.font(Enum.FontWeight.Medium),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
			}),
			Set = e(Button, {
				position = UDim2.fromOffset(210, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Set",
				color = Theme.colors.accent,
				disabled = pending,
				onClick = function()
					local box = luckInputRef.current
					run("setLuck", box and parseAmount(box.Text))
				end,
			}),
			Reset = e(Button, {
				position = UDim2.fromOffset(312, 104),
				size = UDim2.fromOffset(96, 36),
				text = "Reset",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					run("setLuck", 1)
				end,
			}),
		}),
		NameStyle = e(Section, {
			title = "Name style",
			position = UDim2.fromOffset(576, 202),
			size = UDim2.new(1, -576, 0, 190),
		}, {
			Current = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Overhead name style: {NameStyles.get(nameStyle).name}`,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Styles = e("Frame", {
				Position = UDim2.fromOffset(0, 54),
				Size = UDim2.new(1, 0, 1, -54),
				BackgroundTransparency = 1,
			}, styleButtons),
		}),
		Data = e(Section, {
			title = "Data",
			position = UDim2.fromOffset(576, 0),
			size = UDim2.new(1, -576, 0, 190),
		}, {
			Info = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 36),
				Text = "Wipes save your changes right away. Click twice to confirm.",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Wipe = e(Button, {
				position = UDim2.fromOffset(0, 70),
				size = UDim2.new(1, 0, 0, 36),
				text = if armed == "wipeData" then "Click again to confirm" else "Wipe my data",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					confirmThen("wipeData", "[admin] your data was wiped")
				end,
			}),
			WipeAll = e(Button, {
				position = UDim2.fromOffset(0, 114),
				size = UDim2.new(1, 0, 0, 36),
				text = if armed == "wipeAll" then "Click again to confirm" else "Wipe data + reset serials",
				color = Theme.colors.bad,
				disabled = pending,
				onClick = function()
					confirmThen("wipeAll", "[admin] data wiped and serials reset")
				end,
			}),
		}),
	})
end

return React.memo(AdminPage)
