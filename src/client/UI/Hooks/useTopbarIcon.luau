-- a TopbarPlus icon (next to Roblox's own topbar buttons) that toggles one of our windows. the icon is made once and
-- kept selected while the window is open, however it was opened or closed.
-- usage: useTopbarIcon({ image?, label?, caption, order? }, active, onToggle(selected), enabled?, notice?)
-- (enabled = false hides it, notice = true shows TopbarPlus's notice dot until it goes false)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Icon = require(ReplicatedStorage.Packages.TopbarPlus)

local function useTopbarIcon(
	options,
	active: boolean,
	onToggle: (selected: boolean) -> (),
	enabled: boolean?,
	notice: boolean?
)
	local iconRef = React.useRef(nil)
	local toggleRef = React.useRef(onToggle)
	toggleRef.current = onToggle

	React.useEffect(function()
		local icon = Icon.new():setCaption(options.caption):setOrder(options.order or 1)
		if options.image then
			icon:setImage(options.image)
		end
		if options.label then
			icon:setLabel(options.label)
		end
		iconRef.current = icon
		local connection = icon.toggled:Connect(function(selected: boolean)
			toggleRef.current(selected)
		end)
		return function()
			connection:Disconnect()
			iconRef.current = nil
			icon:destroy()
		end
	end, {})

	React.useEffect(function()
		local icon = iconRef.current
		if not icon or icon.isSelected == active then
			return
		end
		if active then
			icon:select()
		else
			icon:deselect()
		end
	end, { active })

	React.useEffect(function()
		local icon = iconRef.current
		if icon then
			icon:setEnabled(enabled ~= false)
		end
	end, { enabled ~= false })

	React.useEffect(function()
		local icon = iconRef.current
		if not icon then
			return
		end
		if notice then
			icon:notify()
		else
			icon:clearNotices()
		end
	end, { notice == true })
end

return useTopbarIcon
