-- short cutscene played between the case spin and the item reveal for Exotic and Divine unboxes: the screen goes
-- dark, rays in the tier's color spin up, then a flash, a shake and a ring as the tier name slams in, and the item
-- rises into view. Divine is longer, with shimmering rays and text and a second ring. click anywhere to skip.
-- props: item, onDone()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Traits = require(Shared.Modifiers.Traits)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local TraitText = require(script.Parent.Parent.Components.TraitText)
local TierGradient = require(script.Parent.Parent.Components.TierGradient)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local RAY_COUNT = 14
local SLAM_AT = 0.95
local FADE_OUT = 0.35

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOut(t: number): number
	return 1 - (1 - clamp01(t)) ^ 3
end

-- a value that goes 0 -> 1 between from and to
local function span(t: number, from: number, to: number): number
	return clamp01((t - from) / (to - from))
end

local function Ring(props)
	local time = props.time
	local startAt = props.startAt
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = time:map(function(t)
			local p = easeOut(span(t, startAt, startAt + 0.9))
			return UDim2.fromOffset(40 + p * 1400, 40 + p * 1400)
		end),
		BackgroundTransparency = 1,
		Visible = time:map(function(t)
			return t >= startAt and t <= startAt + 0.9
		end),
		ZIndex = 4,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", {
			Color = props.color,
			Thickness = 6,
			Transparency = time:map(function(t)
				return span(t, startAt, startAt + 0.9)
			end),
		}),
	})
end

local function RareReveal(props)
	local item = props.item
	local tier = ItemRegistry.tier(item.assetId)
	local info = ItemRegistry.get(item.assetId)
	local divine = tier.id == "divine"
	local duration = if divine then 3 else 2.2
	local time, setTime = React.useBinding(0)
	local done = React.useRef(false)

	local function finish()
		if not done.current then
			done.current = true
			props.onDone()
		end
	end

	React.useLayoutEffect(function()
		local start = os.clock()
		local slammed = false
		Sfx.play("whoosh", 0.8)
		local connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			setTime(t)
			if not slammed and t >= SLAM_AT then
				slammed = true
				Sfx.play("revealMythic", if divine then 0.65 else 0.8)
				Sfx.play("revealMythicSweep")
				if divine then
					Sfx.play("revealRare", 1.2)
				end
			end
			if t >= duration then
				finish()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	-- everything fades out together at the end
	local function fadeOut(t: number): number
		return span(t, duration - FADE_OUT, duration)
	end

	local rays = {}
	for index = 1, RAY_COUNT do
		-- ui rotates around its center, so each ray is a centered holder with the beam in its top half
		rays["Ray" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = time:map(function(t)
				local grow = easeOut(span(t, 0.2, SLAM_AT)) * 0.6 + easeOut(span(t, SLAM_AT, SLAM_AT + 0.4)) * 0.4
				return UDim2.new(0, if index % 2 == 0 then 10 else 22, 1.5 * grow, 0)
			end),
			Rotation = time:map(function(t)
				return (index - 1) * (360 / RAY_COUNT) + t * (if divine then 28 else 18)
			end),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Beam = e("Frame", {
				Size = UDim2.fromScale(1, 0.5),
				BackgroundColor3 = tier.color,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				Fade = e("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0.35),
					}),
				}),
			}),
		})
	end

	local shake = time:map(function(t)
		local p = span(t, SLAM_AT, SLAM_AT + 0.45)
		if p <= 0 or p >= 1 then
			return UDim2.fromScale(0, 0)
		end
		local strength = (1 - p) * (if divine then 14 else 9)
		return UDim2.fromOffset(math.sin(t * 90) * strength, math.cos(t * 77) * strength)
	end)

	local traitIds = Traits.of(item)

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 5, 7),
		BackgroundTransparency = time:map(function(t)
			return math.max(1 - easeOut(span(t, 0, 0.3)) * 0.94, fadeOut(t))
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 1,
		[React.Event.Activated] = finish,
	}, {
		Stage = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			Position = shake,
			BackgroundTransparency = 1,
			GroupTransparency = time:map(fadeOut),
		}, {
			Rays = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, -0.05),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, rays),
			Glow = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = time:map(function(t)
					local p = easeOut(span(t, 0.2, SLAM_AT))
					return UDim2.fromOffset(120 + p * 260, 120 + p * 260)
				end),
				BackgroundColor3 = tier.color,
				BackgroundTransparency = time:map(function(t)
					return 1 - span(t, 0.2, SLAM_AT) * 0.55
				end),
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Soft = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			RingOne = e(Ring, { time = time, startAt = SLAM_AT, color = tier.color }),
			RingTwo = if divine
				then e(Ring, { time = time, startAt = SLAM_AT + 0.35, color = Color3.new(1, 1, 1) })
				else nil,
			Thumbnail = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = time:map(function(t)
					local p = easeOut(span(t, SLAM_AT + 0.15, SLAM_AT + 0.6))
					return UDim2.new(0.5, 0, 0.47 + (1 - p) * 0.12, 0)
				end),
				Size = UDim2.fromScale(0.26, 0.26),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1,
				Image = ItemRegistry.thumbnail(item.assetId, 420),
				ImageTransparency = time:map(function(t)
					return 1 - span(t, SLAM_AT + 0.15, SLAM_AT + 0.5)
				end),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 5,
			}),
			TierName = e(Text, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.new(1, 0, 0, 90),
				Text = string.upper(tier.name),
				TextSize = 84,
				TextColor3 = tier.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = time:map(function(t)
					return 1 - span(t, SLAM_AT - 0.08, SLAM_AT)
				end),
				TextStrokeTransparency = 0.4,
				display = true,
				weight = Enum.FontWeight.Bold,
				ZIndex = 6,
			}, {
				Slam = e("UIScale", {
					Scale = time:map(function(t)
						local p = span(t, SLAM_AT - 0.08, SLAM_AT + 0.12)
						return 1 + (1 - easeOut(p)) * 2.2
					end),
				}),
				Shimmer = e(TierGradient, { tier = tier }),
			}),
			ItemName = e(TraitText, {
				trait = traitIds[1],
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.64),
				Size = UDim2.new(1, 0, 0, 40),
				Text = Traits.fullName(traitIds, info and info.name or "Unknown"),
				TextSize = 34,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = time:map(function(t)
					return 1 - span(t, SLAM_AT + 0.45, SLAM_AT + 0.8)
				end),
				display = true,
				weight = Enum.FontWeight.Bold,
				ZIndex = 6,
			}),
			Hint = e(Text, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Click to skip",
				TextSize = 12,
				TextColor3 = Theme.colors.textFaint,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 6,
			}),
			Flash = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = time:map(function(t)
					local rise = span(t, SLAM_AT - 0.06, SLAM_AT)
					local fall = span(t, SLAM_AT, SLAM_AT + 0.4)
					return 1 - rise * (1 - fall) * (if divine then 0.85 else 0.65)
				end),
				BorderSizePixel = 0,
				ZIndex = 8,
			}),
		}),
	})
end

return RareReveal
