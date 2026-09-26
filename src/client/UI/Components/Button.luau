local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local function Button(props)
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local color = props.color or Theme.colors.panelLight
	local disabled = props.disabled == true

	local background = color
	if disabled then
		background = Theme.colors.panel
	elseif pressed then
		background = color:Lerp(Color3.new(0, 0, 0), 0.15)
	elseif hovered then
		background = color:Lerp(Color3.new(1, 1, 1), 0.1)
	end

	return e("TextButton", {
		Size = props.size or UDim2.fromOffset(140, 36),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = string.upper(props.text or ""),
		FontFace = Theme.display(Enum.FontWeight.Medium),
		TextSize = props.textSize or 16,
		TextColor3 = disabled and Theme.colors.textFaint or Theme.colors.text,
		[React.Event.Activated] = function()
			if not disabled and props.onClick then
				if props.sound ~= false then
					Sfx.play(props.sound or "click")
				end
				props.onClick()
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = disabled and Theme.colors.stroke or color:Lerp(Color3.new(1, 1, 1), 0.18),
			Transparency = 0.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Shade = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		}),
	})
end

return Button
