local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Format = require(Shared.Util.Format)

export type Notification = {
	id: number,
	text: string,
	color: Color3,
}

local Notifications = {
	pushed = Signal.new(),
}

local nextId = 0

function Notifications.push(text: string, color: Color3?)
	nextId += 1
	Notifications.pushed:Fire({
		id = nextId,
		text = text,
		color = color or Color3.fromRGB(235, 238, 245),
	})
end

function Notifications.start()
	Net.events.Announce.OnClientEvent:Connect(function(displayName: string, item)
		local info = ItemRegistry.get(item.assetId)
		local traits = Traits.of(item)
		local trait = Traits.get(traits[1])
		local name = Traits.fullName(traits, info and info.name or "an item")
		local color = trait and trait.uiColor or ItemRegistry.tier(item.assetId).color
		Notifications.push(`{displayName} unboxed {name} ({Format.cash(Valuation.value(item))})`, color)
	end)
end

return Notifications
