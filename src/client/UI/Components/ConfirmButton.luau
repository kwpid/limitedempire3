local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Button)

local RESET_AFTER = 4
local IDLE_COLOR = Color3.fromRGB(150, 44, 44)
local ARMED_COLOR = Color3.fromRGB(205, 58, 58)

local function ConfirmButton(props)
	local phase, setPhase = React.useState("idle")
	local remaining, setRemaining = React.useState(0)
	local holdSeconds = props.holdSeconds or 0

	React.useLayoutEffect(function()
		setPhase("idle")
	end, { props.resetKey })

	React.useLayoutEffect(function()
		if phase == "holding" then
			local cancelled = false
			task.spawn(function()
				local started = os.clock()
				while not cancelled do
					local left = holdSeconds - (os.clock() - started)
					if left <= 0 then
						break
					end
					setRemaining(math.ceil(left))
					task.wait(0.1)
				end
				if not cancelled then
					setPhase("armed")
				end
			end)
			return function()
				cancelled = true
			end
		elseif phase == "armed" then
			local thread = task.delay(RESET_AFTER, setPhase, "idle")
			return function()
				pcall(task.cancel, thread)
			end
		end
		return nil
	end, { phase })

	local text = props.text
	if phase == "holding" then
		text = `Confirm in {remaining}s`
	elseif phase == "armed" then
		text = props.confirmText or "Click to confirm"
	end

	return React.createElement(Button, {
		size = props.size,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		textSize = props.textSize,
		text = text,
		color = if phase == "armed" then ARMED_COLOR else IDLE_COLOR,
		disabled = props.disabled or phase == "holding",
		sound = if phase == "armed" then false else "click",
		onClick = function()
			if phase == "idle" then
				if holdSeconds > 0 then
					setRemaining(math.ceil(holdSeconds))
					setPhase("holding")
				else
					setPhase("armed")
				end
			elseif phase == "armed" then
				setPhase("idle")
				props.onConfirm()
			end
		end,
	})
end

return ConfirmButton
