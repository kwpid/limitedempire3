-- the Games window: a tab per single player game. props: inventory, equipped, pinned, onInspect(uid)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TabBar = require(script.Parent.Parent.Components.TabBar)
local UpgraderPage = require(script.Parent.Games.UpgraderPage)
local TradeUpPage = require(script.Parent.Games.TradeUpPage)
local HigherLowerPage = require(script.Parent.Games.HigherLowerPage)

local e = React.createElement

local TAB_HEIGHT = 32
local TABS = {
	{ id = "upgrader", text = "Upgrader" },
	{ id = "tradeup", text = "Trade-Up" },
	{ id = "hilo", text = "Higher or Lower" },
}

local function GamesPage(props)
	local tab, setTab = React.useState("upgrader")

	local content
	if tab == "upgrader" then
		content = e(UpgraderPage, props)
	elseif tab == "tradeup" then
		content = e(TradeUpPage, props)
	else
		content = e(HigherLowerPage)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Tabs = e(TabBar, {
			size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			tabs = TABS,
			value = tab,
			onChange = setTab,
		}),
		Content = e("Frame", {
			Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
			BackgroundTransparency = 1,
		}, {
			[tab] = content,
		}),
	})
end

return GamesPage
