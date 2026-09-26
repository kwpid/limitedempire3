-- the cases list. a toolbar on top searches case names, series names and the items in each case (so players can find
-- which case drops an item), and filters by price or what they can afford, or sorts.
-- with no search or filter it shows sections: the player's favorites (up to Settings.MAX_FAVORITE_CASES, starred on
-- the cards), Getting Started for new players (until they have opened NEW_PLAYER_OPENS cases), then one section per
-- case series (CaseData.caseSeries). with a search or filter it shows one list of results.
-- hidden rare special items are never searchable.
-- props: cash, opened (cases the player has opened), onSelect(caseId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Shared = ReplicatedStorage.Shared
local CaseRegistry = require(Shared.Cases.CaseRegistry)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local ItemRegistry = require(Shared.Items.ItemRegistry)
local Settings = require(Shared.Settings)
local Theme = require(script.Parent.Parent.Theme)
local Text = require(script.Parent.Parent.Components.Text)
local CaseCard = require(script.Parent.Parent.Components.CaseCard)
local SearchBox = require(script.Parent.Parent.Components.SearchBox)
local Dropdown = require(script.Parent.Parent.Components.Dropdown)
local useSetting = require(script.Parent.Parent.Hooks.useSetting)
local ClientSettings = require(script.Parent.Parent.Parent.Controllers.ClientSettings)
local Notifications = require(script.Parent.Parent.Parent.Controllers.Notifications)
local Sfx = require(script.Parent.Parent.Parent.Controllers.Sfx)

local e = React.createElement

local CARD_SIZE = UDim2.fromOffset(176, 214)
local CARD_GAP = 8
local HEADER_HEIGHT = 44
local TOOLBAR_HEIGHT = 32
local FILTER_WIDTH = 150
-- new players see the Getting Started section until they have opened this many cases
local NEW_PLAYER_OPENS = 50
local STARTER_COUNT = 4

local PRICES = {
	{ id = "all", label = "Any price" },
	{ id = "under10", label = "Under T$10K" },
	{ id = "10to20", label = "T$10K - 20K" },
	{ id = "over20", label = "Over T$20K" },
}
local SHOWS = {
	{ id = "all", label = "All cases" },
	{ id = "afford", label = "Can afford" },
	{ id = "favorites", label = "Favorites" },
}
local SORTS = {
	{ id = "default", label = "Default" },
	{ id = "price_asc", label = "Price: low" },
	{ id = "price_desc", label = "Price: high" },
	{ id = "top_desc", label = "Best item" },
}

-- what each case can be found by, built once: its name, its series name and its visible items (best first)
local searchIndex = nil
local function index()
	if searchIndex then
		return searchIndex
	end
	local seriesNames = {}
	for _, group in CaseRegistry.caseSeries() do
		seriesNames[group.id] = string.lower(group.name)
	end
	searchIndex = {}
	for _, case in CaseRegistry.list() do
		local items = {}
		for _, entry in case.items do
			local info = not entry.special and ItemRegistry.get(entry.assetId)
			if info then
				table.insert(items, { name = info.name, lower = string.lower(info.name), value = entry.value })
			end
		end
		table.sort(items, function(a, b)
			return a.value > b.value
		end)
		searchIndex[case.id] = {
			name = string.lower(case.name),
			series = seriesNames[case.caseSeries] or "",
			items = items,
		}
	end
	return searchIndex
end

-- nil if the case doesn't match, else the matched item's name (or true when the case itself matched)
local function matchCase(case, query: string): (string | boolean)?
	if query == "" then
		return true
	end
	local entry = index()[case.id]
	if string.find(entry.name, query, 1, true) or string.find(entry.series, query, 1, true) then
		return true
	end
	for _, item in entry.items do
		if string.find(item.lower, query, 1, true) then
			return item.name
		end
	end
	return nil
end

local function inPrice(case, price: string): boolean
	if price == "under10" then
		return case.price < 10_000
	elseif price == "10to20" then
		return case.price >= 10_000 and case.price <= 20_000
	elseif price == "over20" then
		return case.price > 20_000
	end
	return true
end

local function Section(props)
	local group = props.group
	local low, high = math.huge, 0
	local cards = {
		Layout = e("UIGridLayout", {
			CellSize = CARD_SIZE,
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, case in group.cases do
		low = math.min(low, case.price)
		high = math.max(high, case.price)
		local match = props.matches and props.matches[case.id]
		cards[case.id] = e(CaseCard, {
			layoutOrder = index,
			case = case,
			cash = props.cash,
			onSelect = props.onSelect,
			favorite = props.favorites[case.id] == true,
			onFavorite = props.onFavorite,
			match = if type(match) == "string" then match else nil,
		})
	end
	local priceText = if #group.cases == 0
		then ""
		elseif low == high then Format.cash(low)
		else `{Format.cash(low)} - {Format.cash(high)}`

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			BackgroundColor3 = Theme.colors.inset,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.radius }),
			Accent = e("Frame", {
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = group.color,
				BorderSizePixel = 0,
			}),
			Fade = e("Frame", {
				Size = UDim2.fromScale(0.5, 1),
				BackgroundColor3 = group.color,
				BorderSizePixel = 0,
			}, {
				Gradient = e("UIGradient", { Transparency = NumberSequence.new(0.82, 1) }),
			}),
			Name = e(Text, {
				Position = UDim2.fromOffset(16, 4),
				Size = UDim2.new(0.6, 0, 0, 22),
				Text = group.name,
				TextSize = 20,
				display = true,
				weight = Enum.FontWeight.Bold,
			}),
			Description = e(Text, {
				Position = UDim2.fromOffset(16, 25),
				Size = UDim2.new(0.7, 0, 0, 14),
				Text = group.description,
				TextSize = 11,
				TextColor3 = Theme.colors.textDim,
			}),
			Info = e(Text, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.3, 0, 1, 0),
				Text = `{#group.cases} {if #group.cases == 1 then "case" else "cases"}   ·   {priceText}`,
				TextSize = 12,
				TextColor3 = Theme.colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		Cards = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, cards),
	})
end

local function CasesPage(props)
	local query, setQuery = React.useState("")
	local price, setPrice = React.useState("all")
	local show, setShow = React.useState("all")
	local sort, setSort = React.useState("default")
	local favoriteIds = useSetting("favoriteCases")
	favoriteIds = if type(favoriteIds) == "table" then favoriteIds else {}

	local favorites = {}
	for _, id in favoriteIds do
		favorites[id] = true
	end

	local function toggleFavorite(caseId: string)
		local nextIds = table.clone(favoriteIds)
		local at = table.find(nextIds, caseId)
		if at then
			table.remove(nextIds, at)
		elseif #nextIds >= Settings.MAX_FAVORITE_CASES then
			Sfx.play("error")
			Notifications.push(`Up to {Settings.MAX_FAVORITE_CASES} favorite cases`, Theme.colors.bad)
			return
		else
			table.insert(nextIds, caseId)
		end
		ClientSettings.set("favoriteCases", nextIds)
	end

	local available = {}
	for _, case in CaseRegistry.list() do
		if CaseRegistry.isAvailable(case) then
			table.insert(available, case)
		end
	end

	local search = string.lower((string.gsub(query, "^%s+", ""):gsub("%s+$", "")))
	local filtering = search ~= "" or price ~= "all" or show ~= "all" or sort ~= "default"
	local shared = {
		cash = props.cash,
		onSelect = props.onSelect,
		favorites = favorites,
		onFavorite = toggleFavorite,
	}

	local sections = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	}
	local empty = false

	if filtering then
		local results, matches = {}, {}
		for _, case in available do
			local match = matchCase(case, search)
			local shown = match ~= nil
				and inPrice(case, price)
				and (show ~= "afford" or props.cash >= case.price)
				and (show ~= "favorites" or favorites[case.id] == true)
			if shown then
				table.insert(results, case)
				matches[case.id] = match
			end
		end
		if sort == "price_asc" then
			table.sort(results, function(a, b)
				return a.price < b.price
			end)
		elseif sort == "price_desc" then
			table.sort(results, function(a, b)
				return a.price > b.price
			end)
		elseif sort == "top_desc" then
			table.sort(results, function(a, b)
				return a.topValue > b.topValue
			end)
		end
		empty = #results == 0
		if not empty then
			sections.Results = e(Section, {
				layoutOrder = 1,
				group = {
					id = "results",
					name = if search ~= "" then `Results for "{query}"` else "Results",
					description = if search ~= ""
						then "Cases whose name, series or items match your search"
						else "Cases matching your filters",
					color = Theme.colors.accent,
					cases = results,
				},
				matches = matches,
				cash = shared.cash,
				onSelect = shared.onSelect,
				favorites = shared.favorites,
				onFavorite = shared.onFavorite,
			})
		end
	else
		local order = 0
		-- favorites first
		local favoriteCases = {}
		for _, id in favoriteIds do
			local case = CaseRegistry.get(id)
			if case and CaseRegistry.isAvailable(case) then
				table.insert(favoriteCases, case)
			end
		end
		if #favoriteCases > 0 then
			order += 1
			sections.Favorites = e(Section, {
				layoutOrder = order,
				group = {
					id = "favorites",
					name = "Favorites",
					description = `Your starred cases (up to {Settings.MAX_FAVORITE_CASES}). Tap the star on a case to add it.`,
					color = Theme.colors.marker,
					cases = favoriteCases,
				},
				cash = shared.cash,
				onSelect = shared.onSelect,
				favorites = shared.favorites,
				onFavorite = shared.onFavorite,
			})
		end
		-- new players: the starter cases, then the cheapest others
		if (props.opened or 0) < NEW_PLAYER_OPENS then
			local starters = table.clone(available)
			table.sort(starters, function(a, b)
				local aStarter, bStarter = a.houseEdge < Config.HouseEdge, b.houseEdge < Config.HouseEdge
				if aStarter ~= bStarter then
					return aStarter
				end
				return a.price < b.price
			end)
			local picked = {}
			for i = 1, math.min(STARTER_COUNT, #starters) do
				table.insert(picked, starters[i])
			end
			order += 1
			sections.GettingStarted = e(Section, {
				layoutOrder = order,
				group = {
					id = "starter",
					name = "Getting Started",
					description = `Cheaper cases to learn with. Starter cases lose less on average. Shown until you've opened {NEW_PLAYER_OPENS} cases.`,
					color = Theme.colors.good,
					cases = picked,
				},
				cash = shared.cash,
				onSelect = shared.onSelect,
				favorites = shared.favorites,
				onFavorite = shared.onFavorite,
			})
		end
		for _, group in CaseRegistry.caseSeries() do
			local shown = table.clone(group)
			shown.cases = {}
			for _, case in group.cases do
				if CaseRegistry.isAvailable(case) then
					table.insert(shown.cases, case)
				end
			end
			if #shown.cases == 0 then
				continue
			end
			order += 1
			sections[group.id] = e(Section, {
				layoutOrder = order,
				group = shown,
				cash = shared.cash,
				onSelect = shared.onSelect,
				favorites = shared.favorites,
				onFavorite = shared.onFavorite,
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Toolbar = e("Frame", {
			Size = UDim2.new(1, -10, 0, TOOLBAR_HEIGHT),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Search = e(SearchBox, {
				layoutOrder = 1,
				size = UDim2.new(1, -(FILTER_WIDTH * 3 + 18), 1, 0),
				value = query,
				placeholder = "Search cases, series or an item to see which case has it...",
				onChange = setQuery,
			}),
			Price = e(Dropdown, {
				layoutOrder = 2,
				size = UDim2.new(0, FILTER_WIDTH, 1, 0),
				label = "Price",
				options = PRICES,
				value = price,
				onChange = setPrice,
			}),
			Show = e(Dropdown, {
				layoutOrder = 3,
				size = UDim2.new(0, FILTER_WIDTH, 1, 0),
				label = "Show",
				options = SHOWS,
				value = show,
				onChange = setShow,
			}),
			Sort = e(Dropdown, {
				layoutOrder = 4,
				size = UDim2.new(0, FILTER_WIDTH, 1, 0),
				label = "Sort",
				options = SORTS,
				value = sort,
				onChange = setSort,
			}),
		}),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(TOOLBAR_HEIGHT + 10)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.colors.stroke,
		}, sections),
		Empty = empty and e(Text, {
			Position = UDim2.fromOffset(0, TOOLBAR_HEIGHT + 30),
			Size = UDim2.new(1, 0, 0, 40),
			Text = if search ~= ""
				then `No case has "{query}". Hidden rare special items don't show up in search.`
				else "No cases match these filters",
			TextColor3 = Theme.colors.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
	})
end

return React.memo(CasesPage)
