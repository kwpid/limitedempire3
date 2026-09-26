local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config)
local Overhead = require(script.Parent.Overhead)
local useSetting = require(script.Parent.Parent.Hooks.useSetting)

local e = React.createElement

local HEAD_WAIT = 10

local function OverheadLayer()
	local heads, setHeads = React.useState({})
	local showOthers = useSetting("showOverheads")
	local showOwn = useSetting("showOwnOverhead")

	React.useLayoutEffect(function()
		local connections: { [Player]: { RBXScriptConnection } } = {}

		local function setHead(player: Player, head: BasePart?)
			setHeads(function(current)
				if current[player] == head then
					return current
				end
				local nextHeads = table.clone(current)
				nextHeads[player] = head
				return nextHeads
			end)
		end

		local function onCharacter(player: Player, character: Model)
			task.spawn(function()
				local head = character:WaitForChild("Head", HEAD_WAIT)
				if head and head:IsA("BasePart") and player.Character == character then
					setHead(player, head)
				end
			end)
		end

		local function track(player: Player)
			if player == Players.LocalPlayer and not Config.Overhead.ShowOwn then
				return
			end
			connections[player] = {
				player.CharacterAdded:Connect(function(character)
					onCharacter(player, character)
				end),
				player.CharacterRemoving:Connect(function()
					setHead(player, nil)
				end),
			}
			if player.Character then
				onCharacter(player, player.Character)
			end
		end

		local function untrack(player: Player)
			for _, connection in connections[player] or {} do
				connection:Disconnect()
			end
			connections[player] = nil
			setHead(player, nil)
		end

		for _, player in Players:GetPlayers() do
			track(player)
		end
		local added = Players.PlayerAdded:Connect(track)
		local removing = Players.PlayerRemoving:Connect(untrack)

		return function()
			added:Disconnect()
			removing:Disconnect()
			for player in connections do
				for _, connection in connections[player] do
					connection:Disconnect()
				end
			end
		end
	end, {})

	local children = {}
	for player, head in heads do
		local isLocal = player == Players.LocalPlayer
		if (isLocal and not showOwn) or (not isLocal and not showOthers) then
			continue
		end
		children["Overhead" .. player.UserId] = e(Overhead, {
			player = player,
			head = head,
		})
	end

	return e("Folder", {}, children)
end

return OverheadLayer
