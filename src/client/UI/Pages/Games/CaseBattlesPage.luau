-- Case Battles. home: Create Lobby / Join Lobby. create: pick cases (rounds) and seats, then create a lobby or play
-- solo against bots straight away. join: the open lobbies. lobby: the seats while waiting, the host can add bots
-- or start (empty seats become bots). battle: a column per seat, every round each column spins and lands on what
-- it opened, totals add up, and the winner takes every item. all rolls come from the server (CaseBattleService).
-- props: cash, onInspect(uid)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local Battles = require(script.Parent.Parent.Parent.Parent.Controllers.Battles)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local MAX_ROUNDS = 10
local SPIN_TIME = 2.4
local HOLD_TIME = 0.9
local ROUND_TIME = SPIN_TIME + HOLD_TIME
local SPIN_FRAMES = 22

local function useBattles()
	local state, setState = React.useState(Battles.get())
	React.useLayoutEffect(function()
		setState(Battles.get())
		local connection = Battles.changed:Connect(setState)
		return function()
			connection:Disconnect()
		end
	end, {})
	return state
end

local function run(action: string, payload: any?, onDone: (() -> ())?)
	task.spawn(function()
		local result = Battles.action(action, payload)
		if not result.ok then
			Sfx.play("error")
			Notifications.push(result.err or "Something went wrong", Theme.colors.bad)
		elseif onDone then
			onDone()
		end
	end)
end

local function CaseIcons(props)
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, caseId in props.cases do
		local case = CaseRegistry.get(caseId)
		children["Case" .. index] = e("ImageLabel", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(props.size or 30, props.size or 30),
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			Image = if case then ItemRegistry.thumbnail(case.iconAssetId, 150) else "",
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", {
				Color = if case then case.color else Theme.colors.stroke,
				Thickness = if props.highlight == index then 2 else 1,
				Transparency = if props.highlight and props.highlight ~= index then 0.6 else 0,
			}),
		})
	end
	return e("Frame", {
		Position = props.position,
		Size = props.frameSize or UDim2.new(1, 0, 0, props.size or 30),
		BackgroundTransparency = 1,
	}, children)
end

local function BigButton(props)
	return e(Button, {
		anchorPoint = props.anchorPoint,
		position = props.position,
		size = props.size,
		text = props.text,
		textSize = 24,
		color = props.color,
		sound = "tab",
		disabled = props.disabled,
		onClick = props.onClick,
	})
end

-- home -----------------------------------------------------------------------------------------------------

local function Home(props)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Title = e(Text, {
			Position = UDim2.fromScale(0, 0.12),
			Size = UDim2.new(1, 0, 0, 44),
			Text = "Case Battles",
			TextSize = 40,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Rules = e(Text, {
			Position = UDim2.new(0, 0, 0.12, 50),
			Size = UDim2.new(1, 0, 0, 36),
			Text = "Everyone opens the same cases. The highest total value wins every item. Empty seats can be filled with bots, so you can play solo.",
			TextSize = 14,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
		}),
		Create = e(BigButton, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(0.5, -8, 0.45, 0),
			size = UDim2.fromOffset(280, 90),
			text = "Create Lobby",
			color = Theme.colors.good,
			onClick = function()
				props.setView("create")
			end,
		}),
		Join = e(BigButton, {
			position = UDim2.new(0.5, 8, 0.45, 0),
			size = UDim2.fromOffset(280, 90),
			text = `Join Lobby ({#props.lobbies})`,
			color = Theme.colors.accent,
			onClick = function()
				props.setView("join")
			end,
		}),
	})
end

-- create ---------------------------------------------------------------------------------------------------

local function Create(props)
	local picks, setPicks = React.useState({})
	local seats, setSeats = React.useState(2)

	local cost = 0
	for _, caseId in picks do
		local case = CaseRegistry.get(caseId)
		cost += case and case.price or 0
	end

	local caseTiles = {}
	for index, case in CaseRegistry.list() do
		caseTiles[case.id] = e("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			[React.Event.Activated] = function()
				if #picks >= MAX_ROUNDS then
					Notifications.push(`Up to {MAX_ROUNDS} cases`, Theme.colors.bad)
					return
				end
				Sfx.play("tab")
				local nextPicks = table.clone(picks)
				table.insert(nextPicks, case.id)
				setPicks(nextPicks)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = case.color, Transparency = 0.5 }),
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				Size = UDim2.fromOffset(56, 56),
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(case.iconAssetId, 150),
			}),
			Name = e(Text, {
				Position = UDim2.new(0, 4, 1, -36),
				Size = UDim2.new(1, -8, 0, 16),
				Text = case.name,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			Price = e(Text, {
				Position = UDim2.new(0, 4, 1, -20),
				Size = UDim2.new(1, -8, 0, 14),
				Text = Format.cash(case.price),
				TextSize = 11,
				TextColor3 = Theme.colors.cash,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	local seatButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for count = 2, 4 do
		seatButtons["Seats" .. count] = e(Button, {
			layoutOrder = count,
			size = UDim2.fromOffset(74, 30),
			text = `{count} players`,
			textSize = 12,
			color = if seats == count then Theme.colors.accent else nil,
			sound = "tab",
			onClick = function()
				setSeats(count)
			end,
		})
	end

	local affordable = props.cash >= cost
	local canCreate = #picks > 0 and affordable

	local function create(solo: boolean)
		run("create", { cases = picks, seats = seats }, function()
			if solo then
				run("start")
			end
		end)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Back = e(Button, {
			size = UDim2.fromOffset(80, 26),
			text = "Back",
			textSize = 13,
			onClick = function()
				props.setView("home")
			end,
		}),
		Hint = e(Text, {
			Position = UDim2.fromOffset(90, 0),
			Size = UDim2.new(1, -440, 0, 26),
			Text = "Click cases to add rounds (repeats are fine)",
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
		}),
		Cases = e(Grid, {
			position = UDim2.fromOffset(0, 34),
			size = UDim2.new(1, -340, 1, -34),
			cellSize = UDim2.fromOffset(100, 104),
			cellPadding = UDim2.fromOffset(5, 5),
		}, caseTiles),
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 328, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			RoundsTitle = e(Text, {
				Size = UDim2.new(1, 0, 0, 18),
				Text = `Rounds  {#picks}/{MAX_ROUNDS}`,
				TextSize = 15,
				display = true,
			}),
			Clear = e(Button, {
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(60, 20),
				text = "Clear",
				textSize = 11,
				disabled = #picks == 0,
				onClick = function()
					setPicks({})
				end,
			}),
			Rounds = e(CaseIcons, {
				position = UDim2.fromOffset(0, 26),
				frameSize = UDim2.new(1, 0, 0, 64),
				cases = picks,
				size = 28,
			}),
			RoundsHint = e(Text, {
				Position = UDim2.fromOffset(0, 60),
				Size = UDim2.new(1, 0, 0, 14),
				Text = if #picks == 0 then "No cases yet" else "",
				TextSize = 11,
				TextColor3 = Theme.colors.textFaint,
			}),
			SeatsTitle = e(Text, {
				Position = UDim2.fromOffset(0, 96),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "Players",
				TextSize = 15,
				display = true,
			}),
			Seats = e("Frame", {
				Position = UDim2.fromOffset(0, 120),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
			}, seatButtons),
			Cost = e(Text, {
				Position = UDim2.fromOffset(0, 168),
				Size = UDim2.new(1, 0, 0, 30),
				Text = `Cost to join {Format.cash(cost)}`,
				TextSize = 22,
				TextColor3 = if affordable then Theme.colors.cash else Theme.colors.bad,
				display = true,
			}),
			CostHint = e(Text, {
				Position = UDim2.fromOffset(0, 198),
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Every player pays this. Refunded if you leave before it starts.",
				TextSize = 11,
				TextColor3 = Theme.colors.textFaint,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
			}),
			Solo = e(Button, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.new(0, 0, 1, -50),
				size = UDim2.new(1, 0, 0, 40),
				text = "Play solo vs bots",
				textSize = 16,
				color = Theme.colors.accent,
				disabled = not canCreate,
				onClick = function()
					create(true)
				end,
			}),
			CreateButton = e(Button, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				size = UDim2.new(1, 0, 0, 44),
				text = if affordable then "Create lobby" else `Not enough {Config.Currency.Name}`,
				textSize = 18,
				color = Theme.colors.good,
				disabled = not canCreate,
				onClick = function()
					create(false)
				end,
			}),
		}),
	})
end

-- join -----------------------------------------------------------------------------------------------------

local function LobbyRow(props)
	local lobby = props.lobby
	local filled = 0
	for _, seat in lobby.seats do
		if seat then
			filled += 1
		end
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Host = e(Text, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0, 200, 0, 18),
			Text = `{lobby.host}'s battle`,
			TextSize = 15,
			display = true,
		}),
		Info = e(Text, {
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(0, 200, 0, 16),
			Text = `{filled}/{lobby.seatCount} players  ·  {#lobby.cases} rounds`,
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
		}),
		Cases = e(CaseIcons, {
			position = UDim2.fromOffset(220, 16),
			frameSize = UDim2.new(1, -470, 0, 32),
			cases = lobby.cases,
			size = 32,
		}),
		Cost = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -120, 0, 0),
			Size = UDim2.new(0, 120, 1, 0),
			Text = Format.cash(lobby.cost),
			TextSize = 16,
			TextColor3 = if props.cash >= lobby.cost then Theme.colors.cash else Theme.colors.bad,
			TextXAlignment = Enum.TextXAlignment.Right,
			display = true,
		}),
		Join = e(Button, {
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -10, 0.5, 0),
			size = UDim2.fromOffset(96, 40),
			text = "Join",
			textSize = 16,
			color = Theme.colors.good,
			disabled = props.cash < lobby.cost,
			onClick = function()
				run("join", { id = lobby.id })
			end,
		}),
	})
end

local function Join(props)
	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, lobby in props.lobbies do
		rows["Lobby" .. lobby.id] = e(LobbyRow, { layoutOrder = index, lobby = lobby, cash = props.cash })
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Back = e(Button, {
			size = UDim2.fromOffset(80, 26),
			text = "Back",
			textSize = 13,
			onClick = function()
				props.setView("home")
			end,
		}),
		Title = e(Text, {
			Position = UDim2.fromOffset(90, 0),
			Size = UDim2.new(1, -90, 0, 26),
			Text = `Open lobbies ({#props.lobbies})`,
			TextSize = 15,
			display = true,
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 1, -34),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
		Empty = if #props.lobbies == 0
			then e(Text, {
				Position = UDim2.fromOffset(0, 60),
				Size = UDim2.new(1, 0, 0, 20),
				Text = "No open lobbies right now. Create one, or play solo against bots.",
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			else nil,
	})
end

-- lobby ----------------------------------------------------------------------------------------------------

local function Lobby(props)
	local lobby = props.lobby
	local isHost = lobby.hostUserId == Players.LocalPlayer.UserId
	local open = 0
	local seatCards = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, lobby.seatCount do
		local seat = lobby.seats[index]
		if not seat then
			open += 1
		end
		seatCards["Seat" .. index] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(200, 150),
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", { Color = if seat then Theme.colors.strokeLight else Theme.colors.stroke }),
			Avatar = seat and not seat.bot and seat.userId and e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 14),
				Size = UDim2.fromOffset(80, 80),
				BackgroundTransparency = 1,
				Image = `rbxthumb://type=AvatarHeadShot&id={seat.userId}&w=150&h=150`,
			}),
			Name = e(Text, {
				Position = UDim2.new(0, 8, 1, -44),
				Size = UDim2.new(1, -16, 0, 20),
				Text = if seat then seat.name else "Waiting for player...",
				TextSize = if seat then 16 else 13,
				TextColor3 = if seat then Theme.colors.text else Theme.colors.textFaint,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = seat ~= nil and seat ~= false,
			}),
			Tag = e(Text, {
				Position = UDim2.new(0, 8, 1, -22),
				Size = UDim2.new(1, -16, 0, 14),
				Text = if seat and seat.bot then "BOT" elseif index == 1 then "HOST" else "",
				TextSize = 11,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Title = e(Text, {
			Size = UDim2.new(1, 0, 0, 30),
			Text = `{lobby.host}'s battle  ·  {Format.cash(lobby.cost)} each`,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
		}),
		Cases = e(CaseIcons, {
			position = UDim2.fromOffset(0, 40),
			frameSize = UDim2.new(1, 0, 0, 40),
			cases = lobby.cases,
			size = 40,
		}),
		Seats = e("Frame", {
			Position = UDim2.fromOffset(0, 100),
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundTransparency = 1,
		}, seatCards),
		Status = e(Text, {
			Position = UDim2.fromOffset(0, 266),
			Size = UDim2.new(1, 0, 0, 20),
			Text = if open > 0
				then `Waiting for {open} more {if open == 1 then "player" else "players"}. It starts when every seat is taken.`
				else "Starting...",
			TextSize = 13,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Buttons = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(620, 44),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			AddBot = isHost and e(Button, {
				layoutOrder = 1,
				size = UDim2.fromOffset(160, 44),
				text = "Add bot",
				textSize = 16,
				disabled = open == 0,
				onClick = function()
					run("addBot")
				end,
			}),
			Start = isHost and e(Button, {
				layoutOrder = 2,
				size = UDim2.fromOffset(240, 44),
				text = "Start (bots fill seats)",
				textSize = 16,
				color = Theme.colors.good,
				onClick = function()
					run("start")
				end,
			}),
			Leave = e(Button, {
				layoutOrder = 3,
				size = UDim2.fromOffset(180, 44),
				text = if isHost then "Close lobby" else "Leave",
				textSize = 16,
				color = Theme.colors.bad,
				onClick = function()
					run("leave")
				end,
			}),
		}),
	})
end

-- battle ---------------------------------------------------------------------------------------------------

local function Column(props)
	local battle = props.battle
	local index = props.index
	local seat = battle.lobby.seats[index]
	local round = props.round
	local roundCount = #battle.rounds
	local won = props.finished and battle.winner == index

	-- a quick cycle of random items from the case that slows down, then the real result
	local filler = React.useMemo(function()
		local rng = Random.new()
		local list = {}
		for r, caseId in battle.lobby.cases do
			list[r] = {}
			for i = 1, SPIN_FRAMES do
				list[r][i] = CaseRegistry.roll(caseId, rng)
			end
		end
		return list
	end, {})

	local total = 0
	local wonItems = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(44, 44),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for r = 1, math.min(props.revealed, roundCount) do
		local item = battle.rounds[r][index]
		total += Valuation.value(item)
		wonItems["Item" .. r] = e("ImageLabel", {
			LayoutOrder = r,
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
			Image = ItemRegistry.thumbnail(item.assetId, 150),
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Stroke = e("UIStroke", { Color = ItemRegistry.tier(item.assetId).color }),
		})
	end

	local current = if round <= roundCount then battle.rounds[round][index] else nil
	local spinImage = props.time:map(function(t)
		if not current then
			return ""
		end
		local roundT = t - (round - 1) * ROUND_TIME
		local p = math.clamp(roundT / SPIN_TIME, 0, 1)
		if p >= 1 then
			return ItemRegistry.thumbnail(current.assetId, 150)
		end
		local frame = math.floor((1 - (1 - p) ^ 2.5) * (SPIN_FRAMES - 1)) + 1
		return ItemRegistry.thumbnail(filler[round][frame], 150)
	end)

	return e("Frame", {
		LayoutOrder = index,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", {
			Color = if won then Theme.colors.good else Theme.colors.stroke,
			Thickness = if won then 3 else 1,
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 20),
			Text = if seat then seat.name .. (if seat.bot then "  (bot)" else "") else "?",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
		}),
		Total = e(Text, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 24),
			Text = Format.cash(total),
			TextSize = 22,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Spin = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.fromOffset(120, 120),
			BackgroundColor3 = Theme.colors.panel,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Color = if current and props.revealed >= round
					then ItemRegistry.tier(current.assetId).color
					else Theme.colors.stroke,
			}),
			Image = e("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = if props.finished then "" else spinImage,
			}),
			Winner = props.finished and e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = if won then "WINNER" else "",
				TextSize = 26,
				TextColor3 = Theme.colors.good,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
		}),
		Items = e("Frame", {
			Position = UDim2.fromOffset(10, 194),
			Size = UDim2.new(1, -20, 1, -204),
			BackgroundTransparency = 1,
		}, wonItems),
	})
end

local function BattleView(props)
	local battle = props.battle
	local roundCount = #battle.rounds
	local time, setTime = React.useBinding(0)
	local revealed, setRevealed = React.useState(0)
	local round = math.min(revealed + 1, roundCount)
	local finished = revealed >= roundCount

	React.useEffect(function()
		local start = os.clock()
		local lastRevealed = 0
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			setTime(t)
			local nowRevealed = 0
			for r = 1, roundCount do
				if t >= (r - 1) * ROUND_TIME + SPIN_TIME then
					nowRevealed = r
				end
			end
			if nowRevealed ~= lastRevealed then
				lastRevealed = nowRevealed
				setRevealed(nowRevealed)
				Sfx.play(if nowRevealed >= roundCount then "revealRare" else "reveal")
				if nowRevealed >= roundCount then
					connection:Disconnect()
				end
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local columns = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / #battle.lobby.seats, -8, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, #battle.lobby.seats do
		columns["Seat" .. index] = e(Column, {
			battle = battle,
			index = index,
			round = round,
			revealed = revealed,
			finished = finished,
			time = time,
		})
	end

	local mySeat = nil
	for index, seat in battle.lobby.seats do
		if seat and seat.userId == Players.LocalPlayer.UserId then
			mySeat = index
		end
	end
	local winnerSeat = battle.lobby.seats[battle.winner]
	local pot = 0
	for _, total in battle.totals do
		pot += total
	end

	local banner
	if finished then
		banner = if battle.winner == mySeat
			then `You won {Format.cash(pot)}! Every item is in your inventory.`
			else `{winnerSeat and winnerSeat.name or "?"} won {Format.cash(pot)}`
	else
		banner = `Round {round} / {roundCount}`
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Banner = e(Text, {
			Size = UDim2.new(1, -200, 0, 30),
			Text = banner,
			TextSize = 22,
			TextColor3 = if finished and battle.winner == mySeat
				then Theme.colors.good
				elseif finished then Theme.colors.bad
				else Theme.colors.text,
			display = true,
		}),
		Rounds = e(CaseIcons, {
			position = UDim2.fromOffset(0, 34),
			frameSize = UDim2.new(1, -200, 0, 30),
			cases = battle.lobby.cases,
			size = 30,
			highlight = if finished then nil else round,
		}),
		Done = e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromOffset(180, 40),
			text = if finished then "Back to battles" else "Skip",
			textSize = 15,
			color = if finished then Theme.colors.good else nil,
			onClick = function()
				Battles.clearBattle()
			end,
		}),
		Columns = e("Frame", {
			Position = UDim2.fromOffset(0, 74),
			Size = UDim2.new(1, 0, 1, -74),
			BackgroundTransparency = 1,
		}, columns),
	})
end

-- page -----------------------------------------------------------------------------------------------------

local function CaseBattlesPage(props)
	local state = useBattles()
	local view, setView = React.useState("home")

	if state.battle then
		return e(BattleView, { battle = state.battle })
	end
	if state.lobby then
		return e(Lobby, { lobby = state.lobby })
	end
	if view == "create" then
		return e(Create, { cash = props.cash or 0, setView = setView })
	elseif view == "join" then
		return e(Join, { lobbies = state.lobbies, cash = props.cash or 0, setView = setView })
	end
	return e(Home, { lobbies = state.lobbies, setView = setView })
end

return CaseBattlesPage
