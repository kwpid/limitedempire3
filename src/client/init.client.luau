local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage.Packages:WaitForChild("ReactRoblox"))

local Controllers = script:WaitForChild("Controllers")
local PlayerState = require(Controllers.PlayerState)
local Notifications = require(Controllers.Notifications)
local Sfx = require(Controllers.Sfx)
local AvatarWear = require(Controllers.AvatarWear)
local Preloader = require(Controllers.Preloader)
local WearRenderer = require(Controllers.WearRenderer)
local Perf = require(Controllers.Perf)
local EffectsToggle = require(Controllers.EffectsToggle)
local App = require(script:WaitForChild("UI"):WaitForChild("App"))
local OverheadLayer = require(script.UI:WaitForChild("Overheads"):WaitForChild("OverheadLayer"))

Perf.start()
WearRenderer.start()
require(Controllers.ItemModels).warmAll()
Preloader.start()
Sfx.start()
PlayerState.start()
Notifications.start()
AvatarWear.start()
EffectsToggle.start()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local focusGui = Instance.new("ScreenGui")
focusGui.Name = "LimitedEmpireFocus"
focusGui.ResetOnSpawn = false
focusGui.IgnoreGuiInset = true
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
