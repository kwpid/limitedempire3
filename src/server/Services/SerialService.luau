-- hands out global serial numbers per item (first dominus ever unboxed is #1, across all servers).
-- uses a datastore counter per asset id (store name comes from DataConfig, so bumping DATA_VERSION restarts serials).
-- if datastores are unavailable (studio without api access) it falls back to a per-server counter so testing works.
-- api: SerialService:Next(assetId) -> number (yields), SerialService:ResetAll() -> number of counters cleared (yields,
-- testing only: every serial restarts at #1, existing items keep the serial they already have)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DataConfig = require(ServerScriptService.Server.Modules.DataConfig)

local RETRIES = 3

local SerialService = {}

local store: DataStore? = nil
local localCounters: { [number]: number } = {}
local usingFallback = false

local function fallback(assetId: number): number
	localCounters[assetId] = (localCounters[assetId] or 0) + 1
	return localCounters[assetId]
end

local function enableFallback(reason: string)
	if not usingFallback then
		usingFallback = true
		warn(`[SerialService] datastore unavailable, using per-server serials ({reason})`)
	end
end

function SerialService:Next(assetId: number): number
	if usingFallback or not store then
		return fallback(assetId)
	end

	local key = tostring(assetId)
	for attempt = 1, RETRIES do
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(current)
				return (current or 0) + 1
			end)
		end)
		if ok and type(result) == "number" then
			return result
		end
		if not ok and (RunService:IsStudio() or tostring(result):find("403")) then
			enableFallback(tostring(result))
			return fallback(assetId)
		end
		task.wait(attempt)
	end

	warn(`[SerialService] failed to get serial for {assetId}, using fallback`)
	return fallback(assetId)
end

function SerialService:ResetAll(): number
	local cleared = 0
	for _ in localCounters do
		cleared += 1
	end
	table.clear(localCounters)
	if usingFallback or not store then
		return cleared
	end

	local ok, pages = pcall(function()
		return (store :: DataStore):ListKeysAsync()
	end)
	if not ok then
		warn(`[SerialService] could not list serial keys: {pages}`)
		return cleared
	end
	while true do
		for _, keyInfo in pages:GetCurrentPage() do
			if pcall((store :: DataStore).RemoveAsync, store, keyInfo.KeyName) then
				cleared += 1
			end
		end
		if pages.IsFinished then
			break
		end
		if not pcall(pages.AdvanceToNextPageAsync, pages) then
			break
		end
	end
	return cleared
end

function SerialService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.SerialStore)
	end)
	if ok then
		store = result
	else
		enableFallback(tostring(result))
	end
end

return SerialService
