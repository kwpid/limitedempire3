-- season window: Overview (season, rank and Season Points, career level and milestones), Quests (daily, weekly,
-- achievements) and Leaderboards (top 100 by Season Points, level or inventory value, from LeaderboardService).
-- props: progress (PlayerState.progress), visible

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Career = require(Shared.Progress.Career)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local NameStyles = require(Shared.Visuals.NameStyles)
local Quests = require(Shared.Progress.Quests)
local Ranks = require(Shared.Progress.Ranks)
local Seasons = require(Shared.Progress.Seasons)
local Titles = require(Shared.Titles)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local TabBar = require(script.Parent.Parent.Components.TabBar)

local e = React.createElement

local TABS = {
	{ id = "overview", text = "Overview" },
	{ id = "quests", text = "Quests" },
	{ id = "leaderboards", text = "Leaderboards" },
}
local BOARDS = {
	{ id = "season", text = "Season Points" },
	{ id = "level", text = "Career Level" },
	{ id = "value", text = "Inventory Value" },
}
local TAB_HEIGHT = 32
local DAY = 86400
local LEADERBOARD_REFRESH = 30
local XP_COLOR = Color3.fromRGB(120, 190, 255)

local function duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // DAY
	local hours = (seconds % DAY) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m {seconds % 60}s`
end

-- re-renders every second, for countdowns
local function useNow(): number
	local now, setNow = React.useState(os.time())
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setNow(os.time())
				end
			end
		end)
		return function()
			running = false
		end
	end, {})
	return now
end

local function Card(props)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		AutomaticSize = props.automaticSize,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, children)
end

local function Bar(props)
	local fill = math.clamp(props.fill or 0, 0, 1)
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Fill = e("Frame", {
			Size = UDim2.fromScale(fill, 1),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
			Visible = fill > 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
		}),
		Label = props.text and e(Text, {
			Size = UDim2.fromScale(1, 1),
			Text = props.text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.6,
			ZIndex = 2,
		}),
	})
end

local function milestoneText(milestone): string
	local parts = {}
	local title = milestone.title and Titles.get(milestone.title)
	if title then
		table.insert(parts, `"{title.name}" title`)
	end
	if milestone.nameStyle then
		table.insert(parts, `{NameStyles.get(milestone.nameStyle).name} name style`)
	end
	return table.concat(parts, " + ")
end

local function Overview(props)
	local progress = props.progress or {}
	local season = progress.season or {}
	local xp = progress.career and progress.career.xp or 0
	local sp = season.sp or 0
	local now = useNow()

	local seasonId, _, endsAt = Seasons.current(now)
	local rank = Ranks.fromSp(sp)
	local rankMin, rankNext = Ranks.bounds(sp)
	local level, into, need = Career.fromXp(xp)
	local multiplier = ReplicatedStorage:GetAttribute("SPMultiplier") or Seasons.SP_MULTIPLIER

	local milestoneRows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local levels = {}
	for milestoneLevel in Career.MILESTONES do
		table.insert(levels, milestoneLevel)
	end
	table.sort(levels)
	local shown = 0
	for _, milestoneLevel in levels do
		if milestoneLevel > level and shown < 5 then
			shown += 1
			milestoneRows["M" .. milestoneLevel] = e("Frame", {
				LayoutOrder = milestoneLevel,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
			}, {
				Level = e(Text, {
					Size = UDim2.fromOffset(70, 20),
					Text = `Level {milestoneLevel}`,
					TextSize = 13,
					TextColor3 = XP_COLOR,
				}),
				Unlock = e(Text, {
					Position = UDim2.fromOffset(76, 0),
					Size = UDim2.new(1, -76, 0, 20),
					Text = milestoneText(Career.MILESTONES[milestoneLevel]),
					TextSize = 13,
					TextColor3 = Theme.colors.textDim,
				}),
			})
		end
	end
	if shown == 0 then
		milestoneRows.Done = e(Text, {
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Every milestone unlocked.",
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
		})
	end

	local tierRows = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tier in Ranks.tiers do
		local reached = sp >= tier.min
		tierRows[tier.id] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1 / #Ranks.tiers, -4, 1, 0),
			BackgroundColor3 = if rank.tier.id == tier.id then Theme.colors.panelLight else Theme.colors.panel,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = rank.tier.id == tier.id and e("UIStroke", { Color = tier.color, Thickness = 1.5 }) or nil,
			Name = e(Text, {
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(1, 0, 0, 18),
				Text = tier.name,
				TextSize = 14,
				display = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if reached then tier.color else Theme.colors.textFaint,
			}),
			Min = e(Text, {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 16),
				Text = `{Format.short(tier.min)}{if tier.id == "legend" then "+" else ""} SP`,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Theme.colors.textDim,
			}),
		})
	end

	local decayPercent = math.floor(Seasons.DECAY_RATE * 100)
	local keepPercent = math.floor(Seasons.SOFT_RESET_KEEP * 100)
	local resetCap = Format.commas(Seasons.SOFT_RESET_CAP)
	local seasonTime = if endsAt then `Ends in {duration(endsAt - now)}` else "Alpha testing, no end date yet"

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Season = e(Card, {
			size = UDim2.new(0.58, -6, 1, 0),
		}, {
			Name = e(Text, {
				Size = UDim2.new(1, 0, 0, 22),
				Text = Seasons.name(seasonId),
				TextSize = 20,
				display = true,
			}),
			Time = e(Text, {
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 0, 16),
				Text = seasonTime,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Multiplier = multiplier ~= 1 and e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(200, 22),
				Text = `{multiplier}x SP EVENT`,
				TextSize = 16,
				display = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.colors.marker,
			}) or nil,
			Rank = e(Text, {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 44),
				Text = rank.name,
				TextSize = 42,
				display = true,
				weight = Enum.FontWeight.Bold,
				TextColor3 = rank.color,
			}),
			Points = e(Text, {
				Position = UDim2.fromOffset(0, 102),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `{Format.commas(sp)} SP   ·   season peak {Format.commas(season.peak or sp)} SP`,
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
			}),
			Bar = e(Bar, {
				position = UDim2.fromOffset(0, 128),
				size = UDim2.new(1, 0, 0, 18),
				fill = if rankNext then (sp - rankMin) / (rankNext - rankMin) else 1,
				color = rank.color,
				text = if rankNext
					then `{Format.commas(rankNext - sp)} SP to {Ranks.fromSp(rankNext).name}`
					else "Top rank",
			}),
			Tiers = e("Frame", {
				Position = UDim2.fromOffset(0, 160),
				Size = UDim2.new(1, 4, 0, 46),
				BackgroundTransparency = 1,
			}, tierRows),
			HowTitle = e(Text, {
				Position = UDim2.fromOffset(0, 222),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "Earning Season Points",
				TextSize = 15,
				display = true,
			}),
			How = e(Text, {
				Position = UDim2.fromOffset(0, 244),
				Size = UDim2.new(1, 0, 1, -244),
				Text = table.concat({
					"• Every case you open (1-3 SP for cheap cases, up to 15 for premium ones)",
					"• Bonus multiplier for pulling Epic or better, traits and stat trackers",
					"• Extra SP when the item is worth more than the case",
					`• Daily login (+{Seasons.DAILY_LOGIN_SP} SP) and completing quests`,
					"",
					`Inactivity: after {Seasons.GRACE_DAYS} days without earning SP you lose {decayPercent}% of your SP every day.`,
					`New season: soft reset, you keep {keepPercent}% of your SP (up to {resetCap}).`,
				}, "\n"),
				TextSize = 13,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Theme.colors.textDim,
			}),
		}),
		Career = e(Card, {
			position = UDim2.new(0.58, 6, 0, 0),
			size = UDim2.new(0.42, -6, 1, 0),
		}, {
			Title = e(Text, {
				Size = UDim2.new(1, 0, 0, 22),
				Text = "Career",
				TextSize = 20,
				display = true,
			}),
			Sub = e(Text, {
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Never resets",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Level = e(Text, {
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 44),
				Text = `Level {level}`,
				TextSize = 42,
				display = true,
				weight = Enum.FontWeight.Bold,
				TextColor3 = XP_COLOR,
			}),
			Total = e(Text, {
				Position = UDim2.fromOffset(0, 102),
				Size = UDim2.new(1, 0, 0, 18),
				Text = `{Format.commas(xp)} XP total`,
				TextSize = 14,
				TextColor3 = Theme.colors.textDim,
			}),
			Bar = e(Bar, {
				position = UDim2.fromOffset(0, 128),
				size = UDim2.new(1, 0, 0, 18),
				fill = if need > 0 then into / need else 1,
				color = XP_COLOR,
				text = if need > 0 then `{Format.commas(into)} / {Format.commas(need)} XP` else "Max level",
			}),
			NextTitle = e(Text, {
				Position = UDim2.fromOffset(0, 162),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "Next milestones",
				TextSize = 15,
				display = true,
			}),
			Milestones = e("Frame", {
				Position = UDim2.fromOffset(0, 186),
				Size = UDim2.new(1, 0, 0, 130),
				BackgroundTransparency = 1,
			}, milestoneRows),
			XpTitle = e(Text, {
				Position = UDim2.fromOffset(0, 318),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "Earning XP",
				TextSize = 15,
				display = true,
			}),
			XpHow = e(Text, {
				Position = UDim2.fromOffset(0, 340),
				Size = UDim2.new(1, 0, 1, -340),
				Text = "Open cases (+1, more for Epic or better, traits and stat trackers), play games, win case battles, log in daily and complete quests.",
				TextSize = 13,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Theme.colors.textDim,
			}),
		}),
	})
end

local function rewardText(reward): string
	local parts = {}
	if reward.xp then
		table.insert(parts, `{Format.short(reward.xp)} XP`)
	end
	if reward.sp then
		table.insert(parts, `{Format.short(reward.sp)} SP`)
	end
	if reward.cash then
		table.insert(parts, Format.cash(reward.cash))
	end
	local title = reward.title and Titles.get(reward.title)
	if title then
		table.insert(parts, `"{title.name}" title`)
	end
	return table.concat(parts, "  ·  ")
end

local function QuestRow(props)
	local quest = props.quest
	local done = props.done
	local value = math.min(props.value or 0, quest.goal)
	local color = Quests.DIFFICULTY_COLORS[quest.difficulty] or Theme.colors.text
	local goalText = if quest.metric == "unboxedValue"
		then `{Format.cash(value)} / {Format.cash(quest.goal)}`
		else `{Format.commas(value)} / {Format.commas(quest.goal)}`
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = if done then 0.5 else 0,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Strip = e("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}),
		Difficulty = e(Text, {
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.fromOffset(60, 16),
			Text = string.upper(quest.difficulty),
			TextSize = 11,
			weight = Enum.FontWeight.Bold,
			TextColor3 = color,
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(76, 5),
			Size = UDim2.new(1, -330, 0, 20),
			Text = quest.name,
			TextSize = 15,
			TextColor3 = if done then Theme.colors.textDim else Theme.colors.text,
		}),
		Reward = e(Text, {
			Position = UDim2.fromOffset(14, 29),
			Size = UDim2.new(1, -270, 0, 16),
			Text = rewardText(quest.reward),
			TextSize = 12,
			TextColor3 = Theme.colors.cash,
		}),
		Progress = e(Bar, {
			position = UDim2.new(1, -240, 0, 17),
			size = UDim2.fromOffset(226, 18),
			fill = if done then 1 else value / quest.goal,
			color = if done then Theme.colors.good else color,
			text = if done then "COMPLETE" else goalText,
		}),
	})
end

local function QuestsTab(props)
	local progress = props.progress or {}
	local quests = progress.quests or {}
	local metrics = progress.metrics or {}
	local now = useNow()
	local today = Seasons.today(now)
	local dailyReset = (today + 1) * DAY - now
	local weeklyReset = (Quests.week(today) + 1) * 7 * DAY - now

	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	}
	local order = 0
	local function header(key: string, text: string, sub: string)
		order += 1
		rows[key] = e("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
		}, {
			Title = e(Text, {
				Position = UDim2.fromOffset(0, 8),
				Size = UDim2.new(0.5, 0, 0, 20),
				Text = text,
				TextSize = 18,
				display = true,
			}),
			Sub = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 10),
				Size = UDim2.new(0.5, 0, 0, 18),
				Text = sub,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.colors.textDim,
			}),
		})
	end
	local function set(key: string, data)
		data = data or {}
		for _, id in data.ids or {} do
			local quest = Quests.get(id)
			if quest then
				order += 1
				rows[key .. id] = e(QuestRow, {
					layoutOrder = order,
					quest = quest,
					value = (data.progress or {})[id],
					done = (data.done or {})[id] == true,
				})
			end
		end
	end

	header("DailyHeader", "Daily quests", `New quests in {duration(dailyReset)}`)
	set("Daily", quests.daily)
	header("WeeklyHeader", "Weekly quests", `New quests in {duration(weeklyReset)}`)
	set("Weekly", quests.weekly)

	local doneCount = 0
	for _, quest in Quests.achievements do
		if (quests.done or {})[quest.id] then
			doneCount += 1
		end
	end
	header("AchievementsHeader", "Achievements", `{doneCount} / {#Quests.achievements} complete`)
	-- unfinished first, then finished, each in list order
	for pass = 1, 2 do
		for _, quest in Quests.achievements do
			local done = (quests.done or {})[quest.id] == true
			if done == (pass == 2) then
				order += 1
				rows["A" .. quest.id] = e(QuestRow, {
					layoutOrder = order,
					quest = quest,
					value = metrics[quest.metric],
					done = done,
				})
			end
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
	}, rows)
end

local function scoreText(board: string, score: number): string
	if board == "season" then
		return `{Format.commas(score)} SP  ·  {Ranks.fromSp(score).name}`
	elseif board == "level" then
		return `Level {(Career.fromXp(score))}  ·  {Format.short(score)} XP`
	end
	return Format.cash(score)
end

local function scoreColor(board: string, score: number): Color3
	if board == "season" then
		return Ranks.fromSp(score).color
	elseif board == "level" then
		return XP_COLOR
	end
	return Theme.colors.cash
end

local RANK_COLORS = {
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(205, 215, 225),
	Color3.fromRGB(215, 140, 80),
}

local function LeaderboardsTab(props)
	local board, setBoard = React.useState("season")
	local data, setData = React.useState({})
	local loading, setLoading = React.useState(false)

	React.useEffect(function()
		if not props.visible then
			return nil
		end
		local running = true
		task.spawn(function()
			while running do
				setLoading(true)
				local ok, result = pcall(Net.functions.GetLeaderboard.InvokeServer, Net.functions.GetLeaderboard, board)
				if not running then
					return
				end
				setLoading(false)
				if ok and type(result) == "table" then
					setData(function(current)
						local nextData = table.clone(current)
						nextData[board] = result.entries
						return nextData
					end)
				end
				task.wait(LEADERBOARD_REFRESH)
			end
		end)
		return function()
			running = false
		end
	end, { board, props.visible } :: { any })

	local entries = data[board]
	local localUserId = Players.LocalPlayer.UserId
	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	}
	for _, entry in entries or {} do
		local mine = entry.userId == localUserId
		rows["R" .. entry.rank] = e("Frame", {
			LayoutOrder = entry.rank,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = if mine then Theme.colors.accent else Theme.colors.panel,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Rank = e(Text, {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(0, 50, 1, 0),
				Text = `#{entry.rank}`,
				TextSize = 16,
				display = true,
				TextColor3 = RANK_COLORS[entry.rank] or Theme.colors.textDim,
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(70, 0),
				Size = UDim2.new(0.5, -70, 1, 0),
				Text = entry.name,
				TextSize = 15,
			}),
			Score = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				Text = scoreText(board, entry.score),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = scoreColor(board, entry.score),
			}),
		})
	end

	local emptyText = if entries == nil then "Loading..." else "Nobody on this board yet."

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Boards = e(TabBar, {
			size = UDim2.new(1, 0, 0, 28),
			tabs = BOARDS,
			value = board,
			onChange = setBoard,
		}),
		Status = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(200, 28),
			Text = if loading then "Refreshing..." else "Top 100",
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.colors.textDim,
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 1, -38),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
		Empty = (entries == nil or #entries == 0) and e(Text, {
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 0, 20),
			Text = emptyText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.textDim,
		}) or nil,
	})
end

local function SeasonPage(props)
	local tab, setTab = React.useState("overview")
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Tabs = e(TabBar, {
			size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			tabs = TABS,
			value = tab,
			onChange = setTab,
		}),
		Content = e("Frame", {
			Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
			BackgroundTransparency = 1,
		}, {
			Overview = tab == "overview" and e(Overview, { progress = props.progress }),
			Quests = tab == "quests" and e(QuestsTab, { progress = props.progress }),
			Leaderboards = tab == "leaderboards"
				and e(LeaderboardsTab, { visible = props.visible and tab == "leaderboards" }),
		}),
	})
end

return SeasonPage
