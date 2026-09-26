-- adds each speaker's title and name style to chat messages (TextChatService only, the legacy chat is ignored).
-- the title goes in front of the name in its color, glow titles get a rich text stroke in their glow color (the
-- closest chat gets to a glow), and the name is tinted with the name style's chatColor, in its font and upper or
-- lower case. chat can't animate or outline.
-- api: ChatTags.start()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameStyles = require(Shared.Visuals.NameStyles)
local Titles = require(Shared.Titles)

-- chat text is small, so the glow stroke stays faint (0 = solid outline, 1 = none)
local GLOW_TRANSPARENCY = 0.75

local ChatTags = {}

local function glowColor(title): Color3?
	local glow = title.glowColor
	if typeof(glow) == "ColorSequence" then
		return glow.Keypoints[1].Value
	end
	return glow
end

local function titleTag(titleId: any): string
	local title = Titles.get(titleId)
	if not title or title.id == Titles.NONE then
		return ""
	end
	local text = `<font color="#{title.color:ToHex()}"><b>{string.upper(title.name)}</b></font>`
	local glow = title.glow and glowColor(title)
	if glow then
		text =
			`<stroke color="#{glow:ToHex()}" joins="round" thickness="1" transparency="{GLOW_TRANSPARENCY}">{text}</stroke>`
	end
	return text .. " "
end

function ChatTags.start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if not player then
			return properties
		end
		local style = NameStyles.get(player:GetAttribute("NameStyle"))
		local name = message.PrefixText
		if style.id ~= "default" then
			-- spaced names would space out the colon too, so chat only takes upper and lower case
			if style.case == "upper" or style.case == "lower" then
				name = NameStyles.transform(style, name)
			end
			local face = if style.font then ` face="{style.font}"` else ""
			name = `<font color="#{style.chatColor:ToHex()}"{face}>{name}</font>`
		end
		properties.PrefixText = titleTag(player:GetAttribute("Title")) .. name
		return properties
	end
end

return ChatTags
