-- redeeming codes (the list is Modules/Codes). each player can redeem each code once, remembered in data.codes.
-- client calls Net.functions.RedeemCode:InvokeServer(text) -> { ok, err?, data = { rewards = { text } } }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Boosts = require(Shared.Economy.Boosts)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local NameStyles = require(Shared.Visuals.NameStyles)
local Codes = require(ServerScriptService.Server.Modules.Codes)
local BoostService = require(script.Parent.BoostService)
local CosmeticService = require(script.Parent.CosmeticService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CodeService = {}

local COOLDOWN = 1
local MAX_LENGTH = 40

local lastTry: { [Player]: number } = {}
-- CODE -> { code, rewards, expiresAt? }
local byCode = {}

local function normalize(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

-- "2026-12-31" -> the last second of that day, UTC
local function parseExpiry(text: any): number?
	if type(text) ~= "string" then
		return nil
	end
	local year, month, day = string.match(text, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
	if not year then
		return nil
	end
	return DateTime.fromUniversalTime(tonumber(year), tonumber(month), tonumber(day), 23, 59, 59).UnixTimestamp
end

-- checks every code once at startup, so a typo shows up as a warning instead of a broken reward
local function load()
	for _, entry in Codes do
		local valid = type(entry.code) == "string" and type(entry.rewards) == "table" and #entry.rewards > 0
		for _, reward in if valid then entry.rewards else {} do
			local isCash = type(reward.cash) == "number" and reward.cash > 0
			local isBoost = Boosts.KINDS[reward.boost] ~= nil
				and type(reward.multiplier) == "number"
				and reward.multiplier > 1
				and type(reward.minutes) == "number"
				and reward.minutes > 0
			local isStyle = NameStyles.exists(reward.nameStyle) and reward.nameStyle ~= "default"
			if not (isCash or isBoost or isStyle) then
				valid = false
			end
		end
		if entry.expires ~= nil and not parseExpiry(entry.expires) then
			valid = false
		end
		if valid then
			byCode[normalize(entry.code)] = {
				code = normalize(entry.code),
				rewards = entry.rewards,
				expiresAt = parseExpiry(entry.expires),
				active = entry.active ~= false,
			}
		else
			warn(`[CodeService] code {tostring(entry.code)} is set up wrong and was skipped`)
		end
	end
end

local function describe(reward): string
	if reward.cash then
		return `+{Format.cash(reward.cash)}`
	elseif reward.nameStyle then
		return `the {NameStyles.get(reward.nameStyle).name} name style`
	end
	return `{reward.multiplier}x {Boosts.KINDS[reward.boost].name} for {reward.minutes} min`
end

function CodeService:Redeem(player: Player, text: any): Types.Result<any>
	if type(text) ~= "string" or #text == 0 or #text > MAX_LENGTH then
		return { ok = false, err = "Enter a code" }
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < COOLDOWN then
		return { ok = false, err = "Slow down a little" }
	end
	lastTry[player] = now

	local data = PlayerDataService:GetData(player)
	if not data then
		return { ok = false, err = "Your data is still loading" }
	end
	local entry = byCode[normalize(text)]
	if not entry or not entry.active then
		return { ok = false, err = "That code doesn't exist" }
	elseif entry.expiresAt and os.time() > entry.expiresAt then
		return { ok = false, err = "That code has expired" }
	end
	data.codes = data.codes or {}
	if data.codes[entry.code] then
		return { ok = false, err = "You already redeemed that code" }
	end

	data.codes[entry.code] = os.time()
	local lines = {}
	for _, reward in entry.rewards do
		if reward.cash then
			PlayerDataService:AddCash(player, reward.cash)
		elseif reward.nameStyle then
			CosmeticService:Unlock(player, "nameStyle", reward.nameStyle)
		else
			BoostService:Add(player, reward.boost, reward.multiplier, reward.minutes)
		end
		table.insert(lines, describe(reward))
	end
	return { ok = true, data = { rewards = lines } }
end

function CodeService:Init()
	load()
	Net.functions.RedeemCode.OnServerInvoke = function(player, text)
		return CodeService:Redeem(player, text)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodeService
