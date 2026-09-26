local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Serial = require(Shared.Modifiers.Serial)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local TraitText = require(script.Parent.Parent.Components.TraitText)
local Button = require(script.Parent.Parent.Components.Button)
local ConfirmButton = require(script.Parent.Parent.Components.ConfirmButton)
local WearBar = require(script.Parent.Parent.Components.WearBar)
local InspectStage = require(script.Parent.Parent.Parent.Controllers.InspectStage)

local e = React.createElement

local BAR_HEIGHT = 70
local CARD_WIDTH = 340

local function Row(props)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
	}, {
		Line = e("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.colors.stroke,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}),
		Label = e(Text, {
			Size = UDim2.fromScale(0.45, 1),
			Text = props.label,
			TextSize = 13,
			TextColor3 = Theme.colors.textFaint,
			display = true,
		}),
		Value = e(TraitText, {
			trait = props.trait,
			Position = UDim2.fromScale(0.45, 0),
			Size = UDim2.fromScale(0.55, 1),
			Text = props.value,
			TextSize = 13,
			TextColor3 = props.color or Theme.colors.text,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function InspectView(props)
	local item = props.item
	local status, setStatus = React.useState("loading")
	local dragging = React.useRef(false)
	local lastPosition = React.useRef(nil)

	React.useLayoutEffect(function()
		local alive = true
		task.spawn(function()
			local ok = InspectStage.show(item)
			if alive then
				setStatus(if ok then "ready" else "failed")
			end
		end)

		local moved = UserInputService.InputChanged:Connect(function(input)
			if not dragging.current then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local position = Vector2.new(input.Position.X, input.Position.Y)
				local last = lastPosition.current
				if last then
					local delta = position - last
					InspectStage.rotate(delta.X, delta.Y)
				end
				lastPosition.current = position
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging.current = false
				lastPosition.current = nil
			end
		end)

		return function()
			alive = false
			moved:Disconnect()
			ended:Disconnect()
			InspectStage.hide()
		end
	end, {})

	local info = ItemRegistry.get(item.assetId)
	local tier = ItemRegistry.tier(item.assetId)
	local trait = Traits.get(item.trait)
	local breakdown = Valuation.breakdown(item)
	local serialLabel = Serial.label(item.serial)
	local accent = trait and trait.uiColor or tier.color

	local actionButtons = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, action in props.actions or {} do
		if action.confirm then
			actionButtons["Action" .. index] = e(ConfirmButton, {
				layoutOrder = index,
				size = UDim2.fromOffset(action.width or 160, 42),
				text = action.text,
				confirmText = action.confirm.text,
				holdSeconds = action.confirm.holdSeconds,
				resetKey = item.uid,
				disabled = action.disabled,
				onConfirm = action.onClick,
			})
		else
			actionButtons["Action" .. index] = e(Button, {
				layoutOrder = index,
				size = UDim2.fromOffset(action.width or 160, 42),
				text = action.text,
				color = action.color,
				disabled = action.disabled,
				sound = action.sound,
				onClick = action.onClick,
			})
		end
	end

	local hint = if status == "loading"
		then "Loading item..."
		elseif status == "failed" then "Preview unavailable for this item"
		else "Drag to rotate   ·   Scroll to zoom"

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging.current = true
				lastPosition.current = Vector2.new(input.Position.X, input.Position.Y)
			end
		end,
		[React.Event.InputChanged] = function(_, input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				InspectStage.zoom(input.Position.Z)
			end
		end,
	}, {
		Header = e("Frame", {
			Position = UDim2.fromOffset(40, 70),
			Size = UDim2.new(0.6, 0, 0, 100),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Caption = e(Text, {
				Size = UDim2.new(1, 0, 0, 18),
				Text = props.caption or "Inspect",
				TextSize = 15,
				TextColor3 = props.captionColor or Theme.colors.textDim,
				display = true,
			}),
			Name = e(TraitText, {
				trait = item.trait,
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, 0, 0, 44),
				Text = (trait and (trait.name .. " ") or "") .. (info and info.name or "Unknown"),
				TextSize = 40,
				TextColor3 = if trait then trait.uiColor else Theme.colors.text,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Rarity = e("Frame", {
				Position = UDim2.fromOffset(0, 70),
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = tier.color,
				BorderSizePixel = 0,
			}, {
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
				Label = e(Text, {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					Text = tier.name .. " Limited",
					TextSize = 14,
					TextColor3 = Color3.fromRGB(15, 15, 18),
					TextTruncate = Enum.TextTruncate.None,
					display = true,
				}),
			}),
		}),
		Close = props.onClose and e(Button, {
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -24, 0, 70),
			size = UDim2.fromOffset(44, 36),
			text = "X",
			zIndex = 3,
			onClick = props.onClose,
		}),
		Card = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 40, 1, -(BAR_HEIGHT + 20)),
			Size = UDim2.fromOffset(CARD_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.colors.topbar,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", { Color = Theme.colors.stroke }),
			Strip = e("Frame", {
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
			}),
			Content = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 16),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
				}),
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				ValueLabel = e(Text, {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 14),
					Text = "Market value",
					TextSize = 12,
					TextColor3 = Theme.colors.textFaint,
					display = true,
				}),
				Value = e(Text, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 34),
					Text = Format.cash(breakdown.total),
					TextSize = 34,
					TextColor3 = Theme.colors.cash,
					display = true,
					weight = Enum.FontWeight.Bold,
				}),
				Wear = e(WearBar, {
					layoutOrder = 3,
					float = item.float,
					size = UDim2.new(1, 0, 0, 40),
				}),
				Rows = e("Frame", {
					LayoutOrder = 4,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, {
					Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
					Serial = e(Row, {
						layoutOrder = 1,
						label = "Serial",
						value = Format.serial(item.serial) .. (serialLabel and `  {serialLabel}` or ""),
						color = serialLabel and Theme.colors.cash or nil,
					}),
					Trait = e(Row, {
						layoutOrder = 2,
						label = "Trait",
						trait = item.trait,
						value = if trait then string.format("%s  x%.2f", trait.name, breakdown.trait) else "None",
						color = if trait then trait.uiColor else Theme.colors.textFaint,
					}),
					Base = e(Row, {
						layoutOrder = 3,
						label = "Base value",
						value = Format.cash(breakdown.base),
					}),
					Released = e(Row, {
						layoutOrder = 4,
						label = "Released",
						value = if info and info.year > 0 then tostring(info.year) else "Unknown",
					}),
				}),
			}),
		}),
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
			BackgroundColor3 = Theme.colors.topbar,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 3,
		}, {
			TopLine = e("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.colors.stroke,
				BorderSizePixel = 0,
			}),
			Hint = e(Text, {
				Position = UDim2.fromOffset(40, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				Text = hint,
				TextSize = 13,
				TextColor3 = Theme.colors.textDim,
			}),
			Actions = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -40, 0, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
				BackgroundTransparency = 1,
			}, actionButtons),
		}),
	})
end

return InspectView
