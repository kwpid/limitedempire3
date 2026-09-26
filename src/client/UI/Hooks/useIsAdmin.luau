local usePlayerAttribute = require(script.Parent.usePlayerAttribute)

local function useIsAdmin(): boolean
	return usePlayerAttribute("IsAdmin") == true
end

return useIsAdmin
