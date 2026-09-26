-- handles case opening requests from clients: validates, charges the price, rolls the item and grants it (or sells
-- it straight away when the player's auto-sell settings say so), then updates their lifetime stats.
-- admin "next unbox" overrides (AdminService) are applied here.
-- api: CaseService:Open(player, caseId) -> { ok, err?, data? = ItemInstance } (data.autoSoldFor is set to the
-- payout when the item was auto-sold, the item is then not in the inventory)
-- client calls it through Net.functions.OpenCase:InvokeServer(caseId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Traits = require(Shared.Modifiers.Traits)
local Settings = require(Shared.Settings)
local Valuation = require(Shared.Modifiers.Valuation)
local Types = require(Shared.Types)
local ItemFactory = require(ServerScriptService.Server.Modules.ItemFactory)
local ItemModelService = require(script.Parent.ItemModelService)
local AdminService = require(script.Parent.AdminService)
local LuckService = require(script.Parent.LuckService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StatTrackerService = require(script.Parent.StatTrackerService)

local CaseService = {}

local lastOpen: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function fail(err: string): Types.Result<Types.ItemInstance>
	return { ok = false, err = err }
end

local function shouldAnnounce(item: Types.ItemInstance): boolean
	local traits = Traits.of(item)
	for _, id in traits do
		local trait = Traits.get(id)
		if trait and trait.announce then
			return true
		end
	end
	return #traits > 1 or Valuation.value(item) >= Config.AnnounceValue
end

local function recordStats(player: Player, price: number, item: Types.ItemInstance, value: number, autoSoldFor: number?)
	local traitCount = #Traits.of(item)
	PlayerDataService:AddStats(player, {
		opened = 1,
		spent = price,
		unboxedValue = value,
		traits = if traitCount > 0 then 1 else 0,
		stacked = if traitCount > 1 then 1 else 0,
		trackers = if item.tracker then 1 else 0,
		specials = if CaseRegistry.isSpecial(item.assetId) then 1 else 0,
		autoSold = if autoSoldFor then 1 else 0,
		soldValue = autoSoldFor or 0,
	})
	local state = PlayerDataService:Get(player)
	if state and value > (state.stats.bestValue or 0) then
		PlayerDataService:SetStats(player, { bestValue = value, bestAssetId = item.assetId })
	end
end

function CaseService:Open(player: Player, caseId: any): Types.Result<Types.ItemInstance>
	if type(caseId) ~= "string" then
		return fail("Invalid case")
	end
	local case = CaseRegistry.get(caseId)
	if not case then
		return fail("Invalid case")
	end
	if busy[player] then
		return fail("Already opening")
	end
	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < Config.OpenCooldown then
		return fail("Slow down")
	end

	busy[player] = true
	lastOpen[player] = now

	if not PlayerDataService:TrySpend(player, case.price) then
		busy[player] = nil
		return fail(`Not enough {Config.Currency.Name}`)
	end

	local luck = LuckService:Get(player)
	local override = AdminService:TakeOverride(player)
	local ok, result = pcall(function()
		local assetId = if override and override.tier
			then ItemFactory.rollTier(caseId, override.tier, luck)
			else ItemFactory.roll(caseId, luck)
		ItemModelService:Prepare(assetId)
		return ItemFactory.create(assetId, caseId, luck, player, override)
	end)
	busy[player] = nil

	if not ok then
		warn(`[CaseService] roll failed for {player.Name}: {result}`)
		PlayerDataService:AddCash(player, case.price)
		return fail("Something went wrong, you were refunded")
	end

	local item: Types.ItemInstance = result
	if not player.Parent then
		return fail("Left the game")
	end

	local value = Valuation.value(item)
	local autoSoldFor = nil
	if Settings.shouldAutoSell(PlayerDataService:GetSettings(player), item) then
		autoSoldFor = math.floor(value * Config.SellRate)
		PlayerDataService:AddCash(player, autoSoldFor)
	else
		PlayerDataService:AddItem(player, item)
	end
	StatTrackerService:CountOpen(player)
	recordStats(player, case.price, item, value, autoSoldFor)

	if shouldAnnounce(item) then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Net.events.Announce:FireClient(other, player.DisplayName, item)
			end
		end
	end

	if autoSoldFor then
		local shown = table.clone(item) :: any
		shown.autoSoldFor = autoSoldFor
		return { ok = true, data = shown }
	end
	return { ok = true, data = item }
end

function CaseService:Init()
	Net.functions.OpenCase.OnServerInvoke = function(player, caseId)
		return CaseService:Open(player, caseId)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
		busy[player] = nil
	end)
end

return CaseService
