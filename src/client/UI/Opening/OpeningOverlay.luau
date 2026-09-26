local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CaseRegistry = require(ReplicatedStorage.Shared.Cases.CaseRegistry)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local Reel = require(script.Parent.Reel)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)
local InspectStage = require(script.Parent.Parent.Parent.Controllers.InspectStage)

local e = React.createElement

local REEL_WIDTH = 900
local REVEAL_DELAY = 0.25

local function OpeningOverlay(props)
	local finished, setFinished = React.useState(false)
	local case = CaseRegistry.get(props.caseId)

	React.useLayoutEffect(function()
		Sfx.play("unlock")
		task.delay(0.15, Sfx.play, "whoosh")
	end, {})

	React.useLayoutEffect(function()
		if props.item then
			InspectStage.prepare(props.item)
		end
	end, { props.item })

	React.useLayoutEffect(function()
		if not (finished and props.item) then
			return nil
		end
		local thread = task.delay(REVEAL_DELAY, props.onRevealed)
		return function()
			pcall(task.cancel, thread)
		end
	end, { finished, props.item })

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.backdrop,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, {
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(REEL_WIDTH, 260),
			BackgroundTransparency = 1,
		}, {
			Caption = e(Text, {
				Size = UDim2.new(1, 0, 0, 20),
				Text = "Unlocking",
				TextSize = 16,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
			}),
			Title = e(Text, {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 40),
				Text = case and case.name or "",
				TextSize = 34,
				TextXAlignment = Enum.TextXAlignment.Center,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Reel = e(Reel, {
				caseId = props.caseId,
				item = props.item,
				width = REEL_WIDTH,
				anchorPoint = Vector2.new(0.5, 1),
				position = UDim2.fromScale(0.5, 1),
				onFinished = function()
					setFinished(true)
				end,
			}),
		}),
	})
end

return OpeningOverlay
