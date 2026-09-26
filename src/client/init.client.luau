local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage.Packages:WaitForChild("ReactRoblox"))

local Controllers = script:WaitForChild("Controllers")
local PlayerState = require(Controllers.PlayerState)
local Screen = require(Controllers.Screen)
local Session = require(Controllers.Session)
local Notifications = require(Controllers.Notifications)
local Sfx = require(Controllers.Sfx)
local AvatarWear = require(Controllers.AvatarWear)
local Preloader = require(Controllers.Preloader)
local WearRenderer = require(Controllers.WearRenderer)
local Perf = require(Controllers.Perf)
local EffectsToggle = require(Controllers.EffectsToggle)
local ChatTags = require(Controllers.ChatTags)
local Battles = require(Controllers.Battles)
local Trades = require(Controllers.Trades)
local Daily = require(Controllers.Daily)
local App = require(script:WaitForChild("UI"):WaitForChild("App"))
local OverheadLayer = require(script.UI:WaitForChild("Overheads"):WaitForChild("OverheadLayer"))

-- equipped tools are always held (AvatarService), so the hotbar and its number key equip / unequip are turned off
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

Perf.start()
Screen.start()
WearRenderer.start()
require(Controllers.ItemModels).warmAll()
Preloader.start()
Sfx.start()
PlayerState.start()
Session.start()
Notifications.start()
AvatarWear.start()
EffectsToggle.start()
ChatTags.start()
Battles.start()
Trades.start()
Daily.start()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local focusGui = Instance.new("ScreenGui")
focusGui.Name = "LimitedEmpireFocus"
focusGui.ResetOnSpawn = false
-- full screen (under Roblox's topbar too) but inside the device safe area, so notches never cut anything off
focusGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
focusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
focusGui.DisplayOrder = 10
focusGui.Parent = playerGui

local root = ReactRoblox.createLegacyRoot(Instance.new("Folder"))

root:render(ReactRoblox.createPortal({
	LimitedEmpire = React.createElement("ScreenGui", {
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		App = React.createElement(App, { focusGui = focusGui }),
	}),
	LimitedEmpireOverheads = React.createElement(OverheadLayer),
}, playerGui))
