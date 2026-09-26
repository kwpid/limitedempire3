-- handles case opening requests from clients: validates, charges the price, rolls the item and grants it.
-- api: CaseService:Open(player, caseId) -> { ok, err?, data? = ItemInstance }
-- client calls it through Net.functions.OpenCase:InvokeServer(caseId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Traits = require(Shared.Modifiers.Traits)
local Valuation = require(Shared.Modifiers.Valuation)
local Types = require(Shared.Types)
local ItemFactory = require(ServerScriptService.Server.Modules.ItemFactory)
local ItemModelService = require(script.Parent.ItemModelService)
local LuckService = require(script.Parent.LuckService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CaseService = {}

local lastOpen: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function fail(err: string): Types.Result<Types.ItemInstance>
	return { ok = false, err = err }
end

local function shouldAnnounce(item: Types.ItemInstance): boolean
	local trait = Traits.get(item.trait)
	return (trait ~= nil and trait.announce) or Valuation.value(item) >= Config.AnnounceValue
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
	local ok, result = pcall(function()
		local assetId = ItemFactory.roll(caseId, luck)
		ItemModelService:Prepare(assetId)
		return ItemFactory.create(assetId, caseId, luck)
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
	PlayerDataService:AddItem(player, item)

	if shouldAnnounce(item) then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Net.events.Announce:FireClient(other, player.DisplayName, item)
			end
		end
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
