local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Format = require(Shared.Util.Format)
local NameStyles = require(Shared.Visuals.NameStyles)
local Titles = require(Shared.Titles)
local ClientSettings = require(script.Parent.ClientSettings)

export type Notification = {
	id: number,
	text: string,
	color: Color3,
}

local PROGRESS_COLORS = {
	level = Color3.fromRGB(120, 190, 255),
	unlock = Color3.fromRGB(236, 238, 242),
	quest = Color3.fromRGB(130, 210, 120),
	rank = Color3.fromRGB(245, 185, 28),
	decay = Color3.fromRGB(220, 110, 90),
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
		if not ClientSettings.get("announcements") then
			return
		end
		local info = ItemRegistry.get(item.assetId)
		local traits = Traits.of(item)
		local trait = Traits.get(traits[1])
		local name = Traits.fullName(traits, info and info.name or "an item")
		local color = trait and trait.uiColor or ItemRegistry.tier(item.assetId).color
		Notifications.push(`{displayName} unboxed {name} ({Format.cash(Valuation.value(item))})`, color)
	end)

	-- career, season and quest toasts from ProgressService
	Net.events.ProgressEvent.OnClientEvent:Connect(function(kind: string, payload)
		if kind == "levelUp" then
			Notifications.push(`Level up! You're now level {payload.level}`, PROGRESS_COLORS.level)
			for _, unlock in payload.unlocks or {} do
				local name = if unlock.kind == "title"
					then (Titles.get(unlock.id) or {}).name
					else NameStyles.get(unlock.id).name
				Notifications.push(
					`Unlocked the {name or unlock.id} {if unlock.kind == "title" then "title" else "name style"}`,
					PROGRESS_COLORS.unlock
				)
			end
		elseif kind == "quest" then
			local reward = payload.reward or {}
			local parts = {}
			if reward.xp then
				table.insert(parts, `{Format.commas(reward.xp)} XP`)
			end
			if reward.sp then
				table.insert(parts, `{Format.commas(reward.sp)} SP`)
			end
			if reward.cash then
				table.insert(parts, Format.cash(reward.cash))
			end
			Notifications.push(`Quest complete: {payload.name}  (+{table.concat(parts, ", ")})`, PROGRESS_COLORS.quest)
		elseif kind == "rankUp" then
			Notifications.push(`Ranked up to {payload.name}!`, PROGRESS_COLORS.rank)
		elseif kind == "newSeason" then
			Notifications.push(
				`{payload.name} has started! You kept {Format.commas(payload.sp)} SP`,
				PROGRESS_COLORS.rank
			)
		elseif kind == "seasonRewards" then
			local place = if payload.placement then ` (#{payload.placement})` else ""
			Notifications.push(
				`{payload.season} ended: {payload.rank}{place}. +{Format.cash(payload.cash)}`,
				PROGRESS_COLORS.rank
			)
			for _, titleId in payload.titles or {} do
				local title = Titles.get(titleId)
				if title then
					Notifications.push(`Unlocked the {title.name} title`, PROGRESS_COLORS.unlock)
				end
			end
		elseif kind == "decay" then
			Notifications.push(`You lost {Format.commas(payload.lost)} SP to inactivity`, PROGRESS_COLORS.decay)
		elseif kind == "login" then
			Notifications.push(`Daily login: +{payload.sp} SP, +{payload.xp} XP`, PROGRESS_COLORS.quest)
		end
	end)
end

return Notifications
