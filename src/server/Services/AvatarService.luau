-- owns character spawning and avatars. players spawn with their own roblox avatar (body, face, clothing) but with
-- every one of their own accessories stripped, plus whatever they have equipped in game. works for any catalog item,
-- the player does not need to own it. character auto loading is turned off, this service spawns and respawns.
-- worn accessories get tagged "LE_WornItem" with LE_Uid/LE_Float attributes so clients can render texture wear.
-- roblox's default name tags are turned off on spawn, the client overhead ui replaces them.
-- a worn face tags the head instead with LE_DecalOnly = true. accessories are matched to items through
-- AccessoryDescription.Instance when available, otherwise by mesh id / name against ItemModelService models.
-- custom items (ItemRegistry.isCustom) are not catalog items, so they are cloned from their real Accessory and
-- added after the description is applied (tagged LE_CustomWorn so the next refresh can swap them out).
--
-- api: AvatarService:SetEquipped(player, uids) -> { ok, err? }, AvatarService:Refresh(player), AvatarService:Spawn(player)
-- client calls it through Net.functions.SetEquipped:InvokeServer({ uid, ... }).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ItemEffects = require(Shared.Visuals.ItemEffects)
local ItemModelService = require(script.Parent.ItemModelService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local WORN_TAG = "LE_WornItem"
local CUSTOM_TAG = "LE_CustomWorn"
local DATA_WAIT = 10

local AvatarService = {}

local baseDescriptions: { [number]: HumanoidDescription } = {}
local applying: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local function getBaseDescription(player: Player): HumanoidDescription
	local cached = baseDescriptions[player.UserId]
	if cached then
		return cached
	end
	local ok, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, math.max(player.UserId, 1))
	local description = ok and result or Instance.new("HumanoidDescription")
	description:SetAccessories({}, true)
	baseDescriptions[player.UserId] = description
	return description
end

local function equippedItems(player: Player): { Types.ItemInstance }
	local state = PlayerDataService:Get(player)
	local items = {}
	if not state then
		return items
	end
	for _, uid in state.equipped do
		local item = state.inventory[uid]
		if item then
			table.insert(items, item)
		end
	end
	return items
end

local function buildDescription(player: Player, items: { Types.ItemInstance }): HumanoidDescription
	local description = getBaseDescription(player):Clone()
	local accessories = {}
	local present = {}

	for _, item in items do
		if ItemRegistry.isCustom(item.assetId) then
			continue
		end
		if ItemRegistry.isFace(item.assetId) then
			description.Face = item.assetId
			description.Head = 0
			continue
		end
		local accessoryType = ItemRegistry.accessoryType(item.assetId)
		if accessoryType and not present[item.assetId] then
			present[item.assetId] = true
			table.insert(accessories, {
				AssetId = item.assetId,
				AccessoryType = accessoryType,
				IsLayered = false,
			})
		end
	end

	description:SetAccessories(accessories, true)
	return description
end

local function markWorn(target: Instance, item: Types.ItemInstance, decalOnly: boolean)
	target:SetAttribute("LE_Uid", item.uid)
	target:SetAttribute("LE_Float", item.float)
	target:SetAttribute("LE_DecalOnly", decalOnly)
	CollectionService:AddTag(target, WORN_TAG)
end

local function matchByDescription(humanoid: Humanoid, pending: { [number]: Types.ItemInstance }, matched: { [Accessory]: Types.ItemInstance })
	local applied = humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not applied then
		return
	end
	for _, child in applied:GetChildren() do
		if not child:IsA("AccessoryDescription") then
			continue
		end
		local item = pending[child.AssetId]
		local ok, accessory = pcall(function()
			return (child :: any).Instance
		end)
		if item and ok and typeof(accessory) == "Instance" and accessory:IsA("Accessory") and not matched[accessory] then
			matched[accessory] = item
			pending[child.AssetId] = nil
		end
	end
end

local function matchByMesh(humanoid: Humanoid, pending: { [number]: Types.ItemInstance }, matched: { [Accessory]: Types.ItemInstance })
	local accessories = humanoid:GetAccessories()
	for assetId, item in pending do
		local model = ItemModelService:Get(assetId)
		if not model then
			continue
		end
		local meshKey = model:GetAttribute("MeshKey")
		local accessoryName = model:GetAttribute("AccessoryName")
		for _, accessory in accessories do
			if matched[accessory] then
				continue
			end
			local key = ItemModelService.meshKey(accessory:FindFirstChild("Handle"))
			if (meshKey ~= "" and key == meshKey) or (accessoryName ~= "" and accessory.Name == accessoryName) then
				matched[accessory] = item
				pending[assetId] = nil
				break
			end
		end
	end
end

local function decorate(humanoid: Humanoid, items: { Types.ItemInstance })
	local character = humanoid.Parent
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if CollectionService:HasTag(descendant, WORN_TAG) then
			CollectionService:RemoveTag(descendant, WORN_TAG)
		end
	end

	local pending: { [number]: Types.ItemInstance } = {}
	local matched: { [Accessory]: Types.ItemInstance } = {}
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and CollectionService:HasTag(accessory, CUSTOM_TAG) then
			accessory:Destroy()
		end
	end
	for _, item in items do
		if ItemRegistry.isCustom(item.assetId) then
			local accessory = ItemModelService:GetAccessory(item.assetId)
			if accessory then
				CollectionService:AddTag(accessory, CUSTOM_TAG)
				humanoid:AddAccessory(accessory)
				matched[accessory] = item
			end
		elseif ItemRegistry.isFace(item.assetId) then
			local head = character:FindFirstChild("Head")
			if head then
				markWorn(head, item, true)
			end
		else
			pending[item.assetId] = item
		end
	end

	matchByDescription(humanoid, pending, matched)
	if next(pending) then
		matchByMesh(humanoid, pending, matched)
	end

	for accessory, item in matched do
		if accessory.Parent then
			ItemEffects.apply(accessory, item)
			markWorn(accessory, item, false)
		end
	end
end

local function apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not character:IsDescendantOf(workspace) then
		return
	end
	local items = equippedItems(player)
	local ok, err = pcall(function()
		humanoid:ApplyDescription(buildDescription(player, items))
	end)
	if not ok then
		warn(`[AvatarService] failed to apply avatar for {player.Name}: {err}`)
		return
	end
	decorate(humanoid, items)
end

function AvatarService:Refresh(player: Player)
	if applying[player] then
		dirty[player] = true
		return
	end
	applying[player] = true
	repeat
		dirty[player] = nil
		apply(player)
	until not dirty[player] or not player.Parent
	applying[player] = nil
end

function AvatarService:Spawn(player: Player)
	if not player.Parent then
		return
	end
	local items = equippedItems(player)
	local ok = pcall(player.LoadCharacterWithHumanoidDescription, player, buildDescription(player, items))
	if not ok then
		pcall(player.LoadCharacter, player)
		AvatarService:Refresh(player)
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		decorate(humanoid, items)
	end
end

function AvatarService:SetEquipped(player: Player, uids: any): Types.Result<nil>
	if type(uids) ~= "table" or #uids > Config.MaxEquipped then
		return { ok = false, err = `You can equip up to {Config.MaxEquipped} items` }
	end
	local clean = {}
	local seen = {}
	local faces = 0
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return { ok = false, err = "Invalid selection" }
		end
		local item = PlayerDataService:GetItem(player, uid)
		if not item or not ItemRegistry.isEquippable(item.assetId) then
			return { ok = false, err = "That item can't be equipped" }
		end
		if ItemRegistry.isFace(item.assetId) then
			faces += 1
			if faces > 1 then
				return { ok = false, err = "Only one face at a time" }
			end
		end
		seen[uid] = true
		table.insert(clean, uid)
	end
	PlayerDataService:SetEquipped(player, clean)
	return { ok = true }
end

local function hookCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Died:Once(function()
		task.wait(Players.RespawnTime)
		if player.Parent and player.Character == character then
			AvatarService:Spawn(player)
		end
	end)
end

local function waitForData(player: Player)
	local deadline = os.clock() + DATA_WAIT
	while not PlayerDataService:Get(player) and player.Parent and os.clock() < deadline do
		task.wait()
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		hookCharacter(player, character)
	end)
	getBaseDescription(player)
	waitForData(player)
	if player.Character then
		hookCharacter(player, player.Character)
		AvatarService:Refresh(player)
	else
		AvatarService:Spawn(player)
	end
end

function AvatarService:Init()
	Players.CharacterAutoLoads = false

	Net.functions.SetEquipped.OnServerInvoke = function(player, uids)
		return AvatarService:SetEquipped(player, uids)
	end
	PlayerDataService.EquippedChanged:Connect(function(player)
		AvatarService:Refresh(player)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		baseDescriptions[player.UserId] = nil
		applying[player] = nil
		dirty[player] = nil
	end)
end

return AvatarService
