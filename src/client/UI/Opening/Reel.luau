local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local CaseRegistry = require(ReplicatedStorage.Shared.Cases.CaseRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.Items.ItemRegistry)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local SpecialTile = require(script.Parent.Parent.Components.SpecialTile)
local TierGradient = require(script.Parent.Parent.Components.TierGradient)

local e = React.createElement

local TILE_W = 140
local TILE_H = 120
local GAP = 4
local STRIDE = TILE_W + GAP
local COUNT = 56
local WIN_INDEX = 48
local DURATION = 6

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 4
end

local function Arrow(props)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position,
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = Theme.colors.marker,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
end

local function Reel(props)
	local width = props.width or 780

	local filler = React.useMemo(function()
		local rng = Random.new()
		local list = {}
		for i = 1, COUNT do
			list[i] = CaseRegistry.roll(props.caseId, rng)
		end
		return list
	end, {})

	local winningAssetId = if props.item then props.item.assetId else filler[WIN_INDEX]
	local strip = React.useMemo(function()
		local list = table.clone(filler)
		list[WIN_INDEX] = winningAssetId
		return list
	end, { winningAssetId })

	local target = React.useMemo(function()
		local jitter = (Random.new():NextNumber() - 0.5) * TILE_W * 0.85
		return (WIN_INDEX - 1) * STRIDE + TILE_W / 2 + jitter - width / 2
	end, {})

	local startOffset = -(width / 2 - TILE_W / 2)
	local offset, setOffset = React.useBinding(startOffset)

	React.useLayoutEffect(function()
		local start = os.clock()
		local finished = false
		local lastTile = nil
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / DURATION, 0, 1)
			local x = startOffset + (target - startOffset) * easeOut(t)
			setOffset(x)
			local tile = math.floor((x + width / 2) / STRIDE)
			if tile ~= lastTile then
				if lastTile then
					Sfx.play("tick", 1 + (math.random() - 0.5) * 0.1)
				end
				lastTile = tile
			end
			if t >= 1 and not finished then
				finished = true
				connection:Disconnect()
				props.onFinished()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local tiles = {}
	for i, assetId in strip do
		if CaseRegistry.isSpecial(assetId) then
			tiles["Tile" .. i] = e(SpecialTile, {
				compact = true,
				position = UDim2.fromOffset((i - 1) * STRIDE, 0),
				size = UDim2.fromOffset(TILE_W, TILE_H),
			})
			continue
		end
		local tier = ItemRegistry.tier(assetId)
		tiles["Tile" .. i] = e("Frame", {
			Position = UDim2.fromOffset((i - 1) * STRIDE, 0),
			Size = UDim2.fromOffset(TILE_W, TILE_H),
			BackgroundColor3 = Theme.colors.panel,
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
						NumberSequenceKeypoint.new(0.4, 1),
						NumberSequenceKeypoint.new(1, 0.65),
					}),
				}),
			}),
			Image = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.47),
				Size = UDim2.fromOffset(92, 92),
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(assetId, 150),
			}),
			Bar = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = tier.color,
				BorderSizePixel = 0,
			}, {
				Shimmer = e(TierGradient, { tier = tier }),
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromOffset(width, TILE_H + 20),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Theme.colors.inset,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
		Strip = e("Frame", {
			Position = offset:map(function(x)
				return UDim2.fromOffset(-x, 10)
			end),
			Size = UDim2.fromOffset(COUNT * STRIDE, TILE_H),
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
		ArrowTop = e(Arrow, { position = UDim2.fromScale(0.5, 0) }),
		ArrowBottom = e(Arrow, { position = UDim2.fromScale(0.5, 1) }),
		ShadeLeft = e("Frame", {
			Size = UDim2.new(0.25, 0, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, {
			Gradient = e("UIGradient", { Transparency = NumberSequence.new(0.1, 1) }),
		}),
		ShadeRight = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.25, 0, 1, 0),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, {
			Gradient = e("UIGradient", { Transparency = NumberSequence.new(1, 0.1) }),
		}),
	})
end

return Reel
