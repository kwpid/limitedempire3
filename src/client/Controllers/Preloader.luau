local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CaseData = require(Shared.Cases.CaseData)
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local ItemRegistry = require(Shared.Items.ItemRegistry)

local Preloader = {}

local BATCH = 40

local seen: { [string]: boolean } = {}
local casesDone: { [string]: boolean } = {}

local function preload(contents: { string })
	local fresh = {}
	for _, content in contents do
		if not seen[content] then
			seen[content] = true
			table.insert(fresh, content)
		end
	end
	for start = 1, #fresh, BATCH do
		local labels = {}
		for i = start, math.min(start + BATCH - 1, #fresh) do
			local label = Instance.new("ImageLabel")
			label.Image = fresh[i]
			table.insert(labels, label)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, labels)
		for _, label in labels do
			label:Destroy()
		end
	end
end

function Preloader.preloadCase(caseId: string)
	if casesDone[caseId] then
		return
	end
	casesDone[caseId] = true
	local case = CaseRegistry.get(caseId)
	if not case then
		return
	end
	task.spawn(function()
		local contents = {}
		for _, item in case.items do
			if not item.special then
				table.insert(contents, ItemRegistry.thumbnail(item.assetId, 150))
			end
		end
		preload(contents)
	end)
end

function Preloader.start()
	task.spawn(function()
		local contents = { `rbxassetid://{CaseData.caseImage}` }
		for _, case in CaseRegistry.list() do
			if case.image then
				table.insert(contents, case.image)
			end
			table.insert(contents, ItemRegistry.thumbnail(case.iconAssetId, 150))
			table.insert(contents, ItemRegistry.thumbnail(case.iconAssetId, 420))
		end
		preload(contents)
	end)
end

return Preloader
