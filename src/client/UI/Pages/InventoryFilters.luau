local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Condition = require(Shared.Modifiers.Condition)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Tiers = require(Shared.Items.Tiers)
local Traits = require(Shared.Modifiers.Traits)
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local SeriesRegistry = require(Shared.Series.SeriesRegistry)

local InventoryFilters = {}

InventoryFilters.rarities = { { id = "all", label = "All" } }
for _, tier in Tiers.custom do
	table.insert(InventoryFilters.rarities, { id = tier.id, label = tier.name, color = tier.color })
end
for index = #Tiers.list, 1, -1 do
	local tier = Tiers.list[index]
	table.insert(InventoryFilters.rarities, { id = tier.id, label = tier.name, color = tier.color })
end

InventoryFilters.shows = {
	{ id = "all", label = "All items" },
	{ id = "equipped", label = "Equipped" },
	{ id = "traits", label = "Has trait" },
	{ id = "stacked", label = "Stacked traits" },
	{ id = "tracker", label = "Stat Tracker" },
	{ id = "mint", label = "Mint / Pristine" },
	{ id = "serial", label = "Top 100 serial" },
}

InventoryFilters.sorts = {
	{ id = "value_desc", label = "Value: high" },
	{ id = "value_asc", label = "Value: low" },
	{ id = "newest", label = "Newest" },
	{ id = "float", label = "Best float" },
	{ id = "serial", label = "Lowest serial" },
}

local SORTERS = {
	value_desc = function(a, b)
		if a.value == b.value then
			return a.item.obtainedAt > b.item.obtainedAt
		end
		return a.value > b.value
	end,
	value_asc = function(a, b)
		if a.value == b.value then
			return a.item.obtainedAt > b.item.obtainedAt
		end
		return a.value < b.value
	end,
	newest = function(a, b)
		if a.item.obtainedAt == b.item.obtainedAt then
			return a.item.uid < b.item.uid
		end
		return a.item.obtainedAt > b.item.obtainedAt
	end,
	float = function(a, b)
		if a.item.float == b.item.float then
			return a.value > b.value
		end
		return a.item.float < b.item.float
	end,
	serial = function(a, b)
		if a.item.serial == b.item.serial then
			return a.value > b.value
		end
		return a.item.serial < b.item.serial
	end,
}

local function searchText(item): string
	local info = ItemRegistry.get(item.assetId)
	local parts = {
		info and info.name or "",
		info and info.acronym or "",
		Traits.label(Traits.of(item)) or "",
		Condition.fromFloat(item.float).name,
		"#" .. item.serial,
		SeriesRegistry.name(CaseRegistry.itemSeries(item)),
		item.tracker and "stat tracker" or "",
	}
	return string.lower(table.concat(parts, " "))
end

local function passesShow(entry, show: string, equippedSet): boolean
	local item = entry.item
	if show == "equipped" then
		return equippedSet[item.uid] == true
	elseif show == "traits" then
		return #Traits.of(item) > 0
	elseif show == "stacked" then
		return #Traits.of(item) > 1
	elseif show == "tracker" then
		return item.tracker ~= nil
	elseif show == "mint" then
		return item.float < Condition.list[2].max
	elseif show == "serial" then
		return item.serial <= 100
	end
	return true
end

function InventoryFilters.apply(entries, filters, equippedSet)
	local query = string.lower(filters.query or "")
	query = query:gsub("^%s+", ""):gsub("%s+$", "")
	local tierId = filters.rarity or "all"
	local show = filters.show or "all"

	local result = {}
	for _, entry in entries do
		if tierId ~= "all" and entry.tierId ~= tierId then
			continue
		end
		if not passesShow(entry, show, equippedSet) then
			continue
		end
		if query ~= "" then
			if not entry.search then
				entry.search = searchText(entry.item)
			end
			if not string.find(entry.search, query, 1, true) then
				continue
			end
		end
		table.insert(result, entry)
	end
	local sorter = SORTERS[filters.sort or "value_desc"] or SORTERS.value_desc
	table.sort(result, function(a, b)
		local aEquipped, bEquipped = equippedSet[a.item.uid] == true, equippedSet[b.item.uid] == true
		if aEquipped ~= bEquipped then
			return aEquipped
		end
		return sorter(a, b)
	end)
	return result
end

return InventoryFilters
