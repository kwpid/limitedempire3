local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Condition = require(ReplicatedStorage.Shared.Modifiers.Condition)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)

local e = React.createElement

-- the condition bar with a marker at the item's float. progress (optional binding, 0 to 1) animates the marker in
-- from the worn end (1.0) to the real float, with the float number and condition name following it.
local function WearBar(props)
	local float = props.float
	local band = Condition.fromFloat(float)
	local shown = if props.progress
		then props.progress:map(function(p)
			return 1 + (float - 1) * math.clamp(p, 0, 1)
		end)
		else nil

	local segments = {}
	for index, entry in Condition.list do
		segments[entry.id] = e("Frame", {
			Position = UDim2.fromScale(entry.min, 0),
			Size = UDim2.fromScale(entry.max - entry.min, 1),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = if entry == band then 0 else 0.55,
			BorderSizePixel = 0,
			LayoutOrder = index,
		})
	end

	return e("Frame", {
		Size = props.size or UDim2.new(1, 0, 0, 40),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Size = UDim2.new(0.5, 0, 0, 16),
			Text = if shown
				then shown:map(function(f)
					return string.upper(Condition.fromFloat(f).name)
				end)
				else band.name,
			TextSize = 13,
			TextColor3 = if shown
				then shown:map(function(f)
					return Condition.fromFloat(f).color
				end)
				else band.color,
			display = true,
		}),
		Value = e(Text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, 0, 0, 16),
			Text = if shown
				then shown:map(function(f)
					return "Float " .. Format.float(f)
				end)
				else "Float " .. Format.float(float),
			TextSize = 12,
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Track = e("Frame", {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundTransparency = 1,
		}, {
			Segments = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, segments),
			Marker = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if shown
					then shown:map(function(f)
						return UDim2.fromScale(math.clamp(f, 0, 1), 0.5)
					end)
					else UDim2.fromScale(math.clamp(float, 0, 1), 0.5),
				Size = UDim2.fromOffset(3, 14),
				BackgroundColor3 = Theme.colors.text,
				BorderSizePixel = 0,
				ZIndex = 2,
			}),
		}),
	})
end

return WearBar
