local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)

local cache: { [string]: number } = {}

local function key(text: string, font: Font, size: number): string
	return `{font.Family}|{font.Weight.Name}|{size}|{text}`
end

local function useTextWidth(text: string, font: Font, size: number): number
	local cacheKey = key(text, font, size)
	local width, setWidth = React.useState(cache[cacheKey] or math.ceil(#text * size * 0.62))

	React.useLayoutEffect(function()
		if cache[cacheKey] then
			setWidth(cache[cacheKey])
			return nil
		end
		local alive = true
		task.spawn(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = text
			params.Font = font
			params.Size = size
			params.Width = 100000
			local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
			if ok then
				cache[cacheKey] = math.ceil(bounds.X)
				if alive then
					setWidth(cache[cacheKey])
				end
			end
		end)
		return function()
			alive = false
		end
	end, { cacheKey })

	return width
end

return useTextWidth
