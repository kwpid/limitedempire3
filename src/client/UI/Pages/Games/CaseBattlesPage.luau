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
local Condition = require(Shared.Modifiers.Condition)
local Format = require(Shared.Util.Format)
local Traits = require(Shared.Modifiers.Traits)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Parent.Components.Text)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Grid = require(script.Parent.Parent.Parent.Components.Grid)
local SpecialTile = require(script.Parent.Parent.Parent.Components.SpecialTile)
local TraitText = require(script.Parent.Parent.Parent.Components.TraitText)
local TrackerBadge = require(script.Parent.Parent.Parent.Components.TrackerBadge)
local Battles = require(script.Parent.Parent.Parent.Parent.Controllers.Battles)
local Notifications = require(script.Parent.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local MAX_ROUNDS = 10
local SPIN_TIME = 3.2
local HOLD_TIME = 1.4
local ROUND_TIME = SPIN_TIME + HOLD_TIME
local REEL_TILES = 34
local REEL_WIN = 29
local TILE_W = 96
local REEL_HEIGHT = 112

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
	-- most expensive first
	local sortedCases = table.clone(CaseRegistry.list())
	table.sort(sortedCases, function(a, b)
		return a.price > b.price
	end)
	for index, case in sortedCases do
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
			Text = if lobby.started
				then "Rolling the battle..."
				elseif
					open > 0
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
				disabled = open == 0 or lobby.started,
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
				disabled = lobby.started,
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
				disabled = lobby.started,
				onClick = function()
					run("leave")
				end,
			}),
		}),
	})
end

-- battle ---------------------------------------------------------------------------------------------------

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 4
end

-- one tile of the reel: the item (or the hidden special tile) over its rarity color
local function ReelTile(props)
	local assetId = props.assetId
	if CaseRegistry.isSpecial(assetId) and not props.reveal then
		return e(SpecialTile, {
			compact = true,
			position = props.position,
			size = UDim2.new(0, TILE_W - 6, 1, -8),
		})
	end
	local tier = ItemRegistry.tier(assetId)
	return e("Frame", {
		Position = props.position,
		Size = UDim2.new(0, TILE_W - 6, 1, -8),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Fade = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = tier.color,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.45, 1),
					NumberSequenceKeypoint.new(1, 0.6),
				}),
			}),
		}),
		Image = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(TILE_W - 22, TILE_W - 22),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(assetId, 150),
		}),
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = tier.color,
			BorderSizePixel = 0,
		}),
	})
end

-- the item a column landed on this round: name in its trait style, value, condition, tracker
local function ResultCard(props)
	local item = props.item
	local info = ItemRegistry.get(item.assetId)
	local tier = ItemRegistry.tier(item.assetId)
	local band = Condition.fromFloat(item.float)
	local traitIds = Traits.of(item)
	return e("Frame", {
		Position = props.position,
		Size = UDim2.new(1, -16, 0, 58),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", { Color = tier.color, Transparency = 0.3 }),
		Name = e(TraitText, {
			trait = traitIds[1],
			Position = UDim2.fromOffset(8, 5),
			Size = UDim2.new(1, -16, 0, 16),
			Text = Traits.fullName(traitIds, info and info.name or "Unknown"),
			TextSize = 13,
			TextColor3 = Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Center,
			weight = Enum.FontWeight.Bold,
		}),
		Value = e(Text, {
			Position = UDim2.fromOffset(8, 22),
			Size = UDim2.new(1, -16, 0, 18),
			Text = Format.cash(Valuation.value(item)),
			TextSize = 17,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Meta = e(Text, {
			Position = UDim2.fromOffset(8, 40),
			Size = UDim2.new(1, -16, 0, 14),
			Text = `{tier.name}  ·  {band.name}  ·  #{item.serial}`,
			TextSize = 11,
			TextColor3 = band.color,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Tracker = item.tracker and e(TrackerBadge, {
			count = item.tracker.opens,
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -4, 0, -10),
			textSize = 10,
			zIndex = 3,
		}),
	})
end

local function WonRow(props)
	local item = props.item
	local info = ItemRegistry.get(item.assetId)
	local tier = ItemRegistry.tier(item.assetId)
	local traitIds = Traits.of(item)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.colors.panel,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Bar = e("Frame", {
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = tier.color,
			BorderSizePixel = 0,
		}),
		Thumb = e("ImageLabel", {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Image = ItemRegistry.thumbnail(item.assetId, 150),
		}),
		Name = e(TraitText, {
			trait = traitIds[1],
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Text = Traits.fullName(traitIds, info and info.name or "Unknown"),
			TextSize = 11,
			TextColor3 = Theme.colors.textDim,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.new(0, 70, 1, 0),
			Text = Format.cash(Valuation.value(item)),
			TextSize = 12,
			TextColor3 = Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function Column(props)
	local battle = props.battle
	local index = props.index
	local seat = battle.lobby.seats[index]
	local round = props.round
	local roundCount = #battle.rounds
	local won = props.finished and battle.winner == index
	local isMine = seat and seat.userId == Players.LocalPlayer.UserId

	-- filler items for every round's reel, the real result goes in at REEL_WIN
	local filler = React.useMemo(function()
		local rng = Random.new()
		local list = {}
		for r, caseId in battle.lobby.cases do
			list[r] = {}
			for i = 1, REEL_TILES do
				list[r][i] = CaseRegistry.roll(caseId, rng)
			end
			list[r][REEL_WIN] = battle.rounds[r][index].assetId
		end
		return list
	end, {})
	local jitter = React.useMemo(function()
		local rng = Random.new()
		local list = {}
		for r = 1, roundCount do
			list[r] = (rng:NextNumber() - 0.5) * TILE_W * 0.7
		end
		return list
	end, {})

	local total = 0
	local rows = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for r = 1, math.min(props.revealed, roundCount) do
		local item = battle.rounds[r][index]
		total += Valuation.value(item)
		rows["Won" .. r] = e(WonRow, { layoutOrder = -r, item = item })
	end

	local spinning = not props.finished and round <= roundCount and props.revealed < round
	local landed = if round <= roundCount and props.revealed >= round then battle.rounds[round][index] else nil
	-- the strip is placed from the reel's center, so it lands on the marker whatever the column width
	local startOffset = TILE_W / 2
	local target = (REEL_WIN - 1) * TILE_W + TILE_W / 2 + (jitter[round] or 0)

	local tiles = {}
	for i, assetId in (filler[math.min(round, roundCount)] or {}) do
		tiles["Tile" .. i] = e(ReelTile, {
			assetId = assetId,
			reveal = i == REEL_WIN and not spinning,
			position = UDim2.fromOffset((i - 1) * TILE_W + 3, 4),
		})
	end

	return e("Frame", {
		LayoutOrder = index,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = e("UIStroke", {
			Color = if won then Theme.colors.good elseif isMine then Theme.colors.strokeLight else Theme.colors.stroke,
			Thickness = if won then 3 else 1,
		}),
		Name = e(Text, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 18),
			Text = if seat then seat.name .. (if seat.bot then "  (bot)" elseif isMine then "  (you)" else "") else "?",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
		}),
		Total = e(Text, {
			Position = UDim2.fromOffset(10, 24),
			Size = UDim2.new(1, -20, 0, 24),
			Text = Format.cash(total),
			TextSize = 22,
			TextColor3 = if won then Theme.colors.good else Theme.colors.cash,
			TextXAlignment = Enum.TextXAlignment.Center,
			display = true,
			weight = Enum.FontWeight.Bold,
		}),
		Reel = e("Frame", {
			Position = UDim2.fromOffset(8, 54),
			Size = UDim2.new(1, -16, 0, REEL_HEIGHT),
			BackgroundColor3 = Theme.colors.backdrop,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Strip = if props.finished
				then nil
				else e("Frame", {
					Size = UDim2.new(0, REEL_TILES * TILE_W, 1, 0),
					Position = props.time:map(function(t)
						local roundT = t - (round - 1) * ROUND_TIME
						local p = easeOut(math.clamp(roundT / SPIN_TIME, 0, 1))
						return UDim2.new(0.5, -(startOffset + (target - startOffset) * p), 0, 0)
					end),
					BackgroundTransparency = 1,
				}, tiles),
			Marker = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Theme.colors.marker,
				BorderSizePixel = 0,
				ZIndex = 5,
			}),
			ShadeLeft = e("Frame", {
				Size = UDim2.new(0.22, 0, 1, 0),
				BackgroundColor3 = Theme.colors.backdrop,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, {
				Gradient = e("UIGradient", { Transparency = NumberSequence.new(0.05, 1) }),
			}),
			ShadeRight = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.22, 0, 1, 0),
				BackgroundColor3 = Theme.colors.backdrop,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, {
				Gradient = e("UIGradient", { Transparency = NumberSequence.new(1, 0.05) }),
			}),
			Winner = props.finished and e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = if won then "WINNER" else "",
				TextSize = 30,
				TextColor3 = Theme.colors.good,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
				ZIndex = 6,
			}),
		}),
		Result = landed and not props.finished and e(ResultCard, {
			item = landed,
			position = UDim2.fromOffset(8, 54 + REEL_HEIGHT + 8),
		}) or nil,
		Won = e("ScrollingFrame", {
			Position = UDim2.fromOffset(8, 54 + REEL_HEIGHT + (if landed and not props.finished then 74 else 8)),
			Size = UDim2.new(1, -16, 1, -(54 + REEL_HEIGHT + (if landed and not props.finished then 82 else 16))),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, rows),
	})
end

local function BattleView(props)
	local battle = props.battle
	local roundCount = #battle.rounds
	local time, setTime = React.useBinding(0)
	local revealed, setRevealed = React.useState(0)
	-- the round being shown comes from the timeline, so a result stays up for HOLD_TIME before the next spin
	local round, setRound = React.useState(1)
	local finished, setFinished = React.useState(false)

	React.useEffect(function()
		local start = os.clock()
		local lastRevealed = 0
		local lastRound = 0
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			setTime(t)
			local currentRound = math.min(math.floor(t / ROUND_TIME) + 1, roundCount)
			if currentRound ~= lastRound then
				lastRound = currentRound
				setRound(currentRound)
				Sfx.play("whoosh", 1.1)
			end
			local nowRevealed = 0
			for r = 1, roundCount do
				if t >= (r - 1) * ROUND_TIME + SPIN_TIME then
					nowRevealed = r
				end
			end
			if nowRevealed ~= lastRevealed then
				lastRevealed = nowRevealed
				setRevealed(nowRevealed)
				Sfx.play("reveal")
			end
			-- the last result stays up for HOLD_TIME too, then the winner is shown
			if t >= roundCount * ROUND_TIME then
				connection:Disconnect()
				setFinished(true)
				Sfx.play("revealRare")
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
