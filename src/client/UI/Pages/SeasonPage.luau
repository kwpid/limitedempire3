-- season window.
--   Overview: a compact bar with the player's season, rank + SP and level + XP, then the Season Points top 100
--   (podium for the top 3, list below).
--   Quests: daily, weekly and achievements.
--   Leaderboards: the other top 100 boards (level, value and lifetime stats, Shared/Progress/Leaderboards).
-- props: progress (PlayerState.progress), visible

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Career = require(Shared.Progress.Career)
local Format = require(Shared.Util.Format)
local Leaderboards = require(Shared.Progress.Leaderboards)
local Net = require(Shared.Net)
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
local OTHER_BOARDS = {}
for _, board in Leaderboards.list do
	if board.id ~= "season" then
		table.insert(OTHER_BOARDS, { id = board.id, text = board.name })
	end
end

local TAB_HEIGHT = 32
local SUMMARY_HEIGHT = 78
local PODIUM_HEIGHT = 168
local ROW_HEIGHT = 34
local DAY = 86400
local REFRESH = 30
local XP_COLOR = Color3.fromRGB(120, 190, 255)
local PLACE_COLORS = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(200, 212, 225),
	Color3.fromRGB(215, 140, 80),
}

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
	return `{minutes}m`
end

-- re-renders every `interval` seconds, for countdowns
local function useNow(interval: number): number
	local now, setNow = React.useState(os.time())
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(interval)
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

local function panel(props, children)
	children.Corner = e("UICorner", { CornerRadius = Theme.radius })
	children.Stroke = e("UIStroke", { Color = Theme.colors.stroke })
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = props.color or Theme.colors.inset,
		BackgroundTransparency = props.transparency or 0,
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
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Fill = fill > 0 and e("Frame", {
			Size = UDim2.fromScale(fill, 1),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}) or nil,
	})
end

local function formatScore(boardId: string, score: number): string
	local board = Leaderboards.get(boardId)
	local format = board and board.format
	if format == "sp" then
		return `{Format.commas(score)} SP`
	elseif format == "level" then
		return `Lv {(Career.fromXp(score))}`
	elseif format == "cash" then
		return Format.cash(score)
	end
	return Format.commas(score)
end

local function scoreColor(boardId: string, score: number): Color3
	local board = Leaderboards.get(boardId)
	local format = board and board.format
	if format == "sp" then
		return Ranks.fromSp(score).color
	elseif format == "level" then
		return XP_COLOR
	elseif format == "cash" then
		return Theme.colors.cash
	end
	return Theme.colors.text
end

-- one stat block of the summary bar: small caption, big value, a bar and the numbers under it
local function Stat(props)
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, {
		Caption = e(Text, {
			Size = UDim2.new(1, 0, 0, 14),
			Text = props.caption,
			TextSize = 12,
			TextColor3 = Theme.colors.textFaint,
		}),
		Value = e(Text, {
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 28),
			Text = props.value,
			TextSize = 26,
			display = true,
			weight = Enum.FontWeight.Bold,
			TextColor3 = props.color,
		}),
		Bar = props.fill and e(Bar, {
			position = UDim2.fromOffset(0, 46),
			size = UDim2.new(1, 0, 0, 6),
			fill = props.fill,
			color = props.color,
		}) or nil,
		Detail = e(Text, {
			Position = UDim2.fromOffset(0, 54),
			Size = UDim2.new(1, 0, 0, 14),
			Text = props.detail or "",
			TextSize = 11,
			TextColor3 = Theme.colors.textDim,
		}),
	})
end

local function Summary(props)
	local progress = props.progress or {}
	local season = progress.season or {}
	local sp = season.sp or 0
	local xp = progress.career and progress.career.xp or 0
	local now = useNow(30)

	local seasonId, _, endsAt = Seasons.current(now)
	local rank = Ranks.fromSp(sp)
	local rankMin, rankNext = Ranks.bounds(sp)
	local level, into, need = Career.fromXp(xp)
	local multiplier = ReplicatedStorage:GetAttribute("SPMultiplier") or Seasons.SP_MULTIPLIER

	return panel({ size = UDim2.new(1, 0, 0, SUMMARY_HEIGHT) }, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Season = e(Stat, {
			size = UDim2.new(0.26, -12, 1, 0),
			caption = if multiplier ~= 1 then `{multiplier}x SP EVENT` else "SEASON",
			value = Seasons.name(seasonId),
			color = if multiplier ~= 1 then Theme.colors.marker else Theme.colors.text,
			detail = if endsAt then `Ends in {duration(endsAt - now)}` else "No end date yet",
		}),
		Rank = e(Stat, {
			position = UDim2.fromScale(0.26, 0),
			size = UDim2.new(0.4, -24, 1, 0),
			caption = "RANK",
			value = rank.name,
			color = rank.color,
			fill = if rankNext then (sp - rankMin) / (rankNext - rankMin) else 1,
			detail = if rankNext
				then `{Format.commas(sp)} / {Format.commas(rankNext)} SP`
				else `{Format.commas(sp)} SP`,
		}),
		Level = e(Stat, {
			position = UDim2.fromScale(0.66, 0),
			size = UDim2.new(0.34, 0, 1, 0),
			caption = "CAREER",
			value = `Level {level}`,
			color = XP_COLOR,
			fill = if need > 0 then into / need else 1,
			detail = if need > 0 then `{Format.commas(into)} / {Format.commas(need)} XP` else "Max level",
		}),
	})
end

-- fetches a board while visible and every REFRESH seconds
local function useBoard(boardId: string, visible: boolean)
	local boards, setBoards = React.useState({})
	React.useEffect(function()
		if not visible then
			return nil
		end
		local running = true
		task.spawn(function()
			while running do
				local ok, result =
					pcall(Net.functions.GetLeaderboard.InvokeServer, Net.functions.GetLeaderboard, boardId)
				if not running then
					return
				end
				if ok and type(result) == "table" then
					setBoards(function(current)
						local nextBoards = table.clone(current)
						nextBoards[boardId] = result
						return nextBoards
					end)
				end
				task.wait(REFRESH)
			end
		end)
		return function()
			running = false
		end
	end, { boardId, visible } :: { any })
	return boards[boardId]
end

local function PodiumSpot(props)
	local entry = props.entry
	local place = props.place
	local color = PLACE_COLORS[place]
	local blockHeight = ({ 64, 44, 30 })[place]
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(props.x, 1),
		Size = UDim2.new(0.3, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		Block = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, blockHeight),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = color, Transparency = 0.4 }),
			Place = e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = `#{place}`,
				TextSize = if place == 1 then 30 else 24,
				display = true,
				weight = Enum.FontWeight.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = color,
			}),
		}),
		Player = entry and e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -(blockHeight + 4)),
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundTransparency = 1,
		}, {
			Avatar = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(52, 52),
				BackgroundColor3 = Theme.colors.panel,
				Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=150&h=150`,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", { Color = color, Thickness = 2 }),
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(0, 55),
				Size = UDim2.new(1, 0, 0, 16),
				Text = entry.name,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Score = e(Text, {
				Position = UDim2.fromOffset(0, 72),
				Size = UDim2.new(1, 0, 0, 16),
				Text = formatScore(props.boardId, entry.score),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = scoreColor(props.boardId, entry.score),
			}),
		}) or nil,
	})
end

local function Row(props)
	local entry = props.entry
	return e("Frame", {
		LayoutOrder = entry.rank,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = if props.mine then Theme.colors.accent else Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Rank = e(Text, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0, 44, 1, 0),
			Text = `#{entry.rank}`,
			TextSize = 15,
			display = true,
			TextColor3 = Theme.colors.textDim,
		}),
		Avatar = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 58, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.colors.inset,
			Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=48&h=48`,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(92, 0),
			Size = UDim2.new(0.5, -92, 1, 0),
			Text = entry.name,
			TextSize = 14,
		}),
		Score = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = formatScore(props.boardId, entry.score),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = scoreColor(props.boardId, entry.score),
		}),
	})
end

-- podium for the top 3, scrolling list for 4 to 100
local function Board(props)
	local data = useBoard(props.boardId, props.visible)
	local entries = data and data.entries
	local localUserId = Players.LocalPlayer.UserId

	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	}
	for index = 4, entries and #entries or 0 do
		local entry = entries[index]
		rows["R" .. entry.rank] = e(Row, { entry = entry, boardId = props.boardId, mine = entry.userId == localUserId })
	end

	local empty = nil
	if entries == nil then
		empty = "Loading..."
	elseif #entries == 0 then
		empty = if data.minScore and data.minScore > 1
			then `Reach Legend ({Format.commas(data.minScore)} SP) to get on the board`
			else "Nobody here yet"
	end

	local podium = entries or {}
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, {
		Podium = panel({ size = UDim2.new(1, 0, 0, PODIUM_HEIGHT) }, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 40),
				PaddingRight = UDim.new(0, 40),
			}),
			Second = e(PodiumSpot, { place = 2, x = 0.17, entry = podium[2], boardId = props.boardId }),
			First = e(PodiumSpot, { place = 1, x = 0.5, entry = podium[1], boardId = props.boardId }),
			Third = e(PodiumSpot, { place = 3, x = 0.83, entry = podium[3], boardId = props.boardId }),
			Empty = empty and e(Text, {
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 0, 20),
				Text = empty,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Theme.colors.textDim,
			}) or nil,
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, PODIUM_HEIGHT + 8),
			Size = UDim2.new(1, 0, 1, -(PODIUM_HEIGHT + 8)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
	})
end

local function Overview(props)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Summary = e(Summary, { progress = props.progress }),
		Title = e(Text, {
			Position = UDim2.fromOffset(0, SUMMARY_HEIGHT + 8),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Season top 100",
			TextSize = 17,
			display = true,
		}),
		Board = e(Board, {
			boardId = "season",
			visible = props.visible,
			position = UDim2.fromOffset(0, SUMMARY_HEIGHT + 34),
			size = UDim2.new(1, 0, 1, -(SUMMARY_HEIGHT + 34)),
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
		table.insert(parts, `{title.name} title`)
	end
	return table.concat(parts, "  ·  ")
end

local function QuestRow(props)
	local quest = props.quest
	local done = props.done
	local value = math.min(props.value or 0, quest.goal)
	local color = Quests.DIFFICULTY_COLORS[quest.difficulty] or Theme.colors.text
	local goalText = if quest.metric == "unboxedValue"
		then `{Format.short(value)} / {Format.short(quest.goal)}`
		else `{Format.commas(value)} / {Format.commas(quest.goal)}`
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 44),
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
		Name = e(Text, {
			Position = UDim2.fromOffset(14, 4),
			Size = UDim2.new(1, -260, 0, 20),
			Text = quest.name,
			TextSize = 15,
			TextColor3 = if done then Theme.colors.textDim else Theme.colors.text,
		}),
		Reward = e(Text, {
			Position = UDim2.fromOffset(14, 23),
			Size = UDim2.new(1, -260, 0, 16),
			Text = rewardText(quest.reward),
			TextSize = 12,
			TextColor3 = if done then Theme.colors.textFaint else Theme.colors.cash,
		}),
		Progress = e(Bar, {
			position = UDim2.new(1, -226, 0, 12),
			size = UDim2.fromOffset(140, 8),
			fill = if done then 1 else value / quest.goal,
			color = if done then Theme.colors.good else color,
		}),
		Count = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 76, 1, 0),
			Text = if done then "✓" else goalText,
			TextSize = if done then 18 else 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if done then Theme.colors.good else Theme.colors.textDim,
		}),
	})
end

local function QuestsTab(props)
	local progress = props.progress or {}
	local quests = progress.quests or {}
	local metrics = progress.metrics or {}
	local now = useNow(30)
	local today = Seasons.today(now)

	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	}
	local order = 0
	local function header(key: string, text: string, sub: string)
		order += 1
		rows[key] = e("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
		}, {
			Title = e(Text, {
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(0.5, 0, 0, 20),
				Text = text,
				TextSize = 17,
				display = true,
			}),
			Sub = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 8),
				Size = UDim2.new(0.5, 0, 0, 18),
				Text = sub,
				TextSize = 12,
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

	header("DailyHeader", "Daily", `Resets in {duration((today + 1) * DAY - now)}`)
	set("Daily", quests.daily)
	header("WeeklyHeader", "Weekly", `Resets in {duration((Quests.week(today) + 1) * 7 * DAY - now)}`)
	set("Weekly", quests.weekly)

	local done = quests.done or {}
	local doneCount = 0
	for _, quest in Quests.achievements do
		if done[quest.id] then
			doneCount += 1
		end
	end
	header("AchievementsHeader", "Achievements", `{doneCount} / {#Quests.achievements}`)
	-- unfinished first, then finished, each in list order
	for pass = 1, 2 do
		for _, quest in Quests.achievements do
			local finished = done[quest.id] == true
			if finished == (pass == 2) then
				order += 1
				rows["A" .. quest.id] = e(QuestRow, {
					layoutOrder = order,
					quest = quest,
					value = metrics[quest.metric],
					done = finished,
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
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.colors.stroke,
	}, rows)
end

local function LeaderboardsTab(props)
	local boardId, setBoardId = React.useState(OTHER_BOARDS[1].id)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Boards = e(TabBar, {
			size = UDim2.new(1, 0, 0, 28),
			tabs = OTHER_BOARDS,
			value = boardId,
			onChange = setBoardId,
		}),
		Board = e(Board, {
			boardId = boardId,
			visible = props.visible,
			position = UDim2.fromOffset(0, 36),
			size = UDim2.new(1, 0, 1, -36),
		}),
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
			Overview = tab == "overview" and e(Overview, {
				progress = props.progress,
				visible = props.visible,
			}),
			Quests = tab == "quests" and e(QuestsTab, { progress = props.progress }),
			Leaderboards = tab == "leaderboards" and e(LeaderboardsTab, { visible = props.visible }),
		}),
	})
end

return SeasonPage
