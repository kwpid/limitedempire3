local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Text)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)

local e = React.createElement

local LIFETIME = 4
local MAX_VISIBLE = 4

local function Toasts()
	local toasts, setToasts = React.useState({})

	React.useLayoutEffect(function()
		local connection = Notifications.pushed:Connect(function(toast)
			setToasts(function(current)
				local nextList = table.clone(current)
				table.insert(nextList, toast)
				while #nextList > MAX_VISIBLE do
					table.remove(nextList, 1)
				end
				return nextList
			end)
			task.delay(LIFETIME, function()
				setToasts(function(current)
					local nextList = {}
					for _, other in current do
						if other.id ~= toast.id then
							table.insert(nextList, other)
						end
					end
					return nextList
				end)
			end)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local children = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, toast in toasts do
		children["Toast" .. toast.id] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.colors.topbar,
			BorderSizePixel = 0,
		}, {
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Strip = e("Frame", {
				Position = UDim2.fromOffset(-14, 0),
				Size = UDim2.new(0, 3, 1, 0),
				BackgroundColor3 = toast.color,
				BorderSizePixel = 0,
			}),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
			Label = e(Text, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = toast.text,
				TextSize = 13,
				TextColor3 = toast.color,
				TextTruncate = Enum.TextTruncate.None,
			}),
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, children)
end

return Toasts
