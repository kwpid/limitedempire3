-- server entry point. requires every ModuleScript in Services, calls :Init() on all of them, then :Start().
-- a service is a module returning a table with optional Init/Start methods. Init is for setup that other
-- services might rely on (signals, connections), Start is for anything that yields or talks to other services.
-- a service that errors while loading is skipped with a warning so it can't take every other service down with it.

local Services = script:WaitForChild("Services")

local loaded = {}
for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			loaded[module.Name] = result
		else
			warn(`[Server] {module.Name} failed to load, it will not run: {result}`)
		end
	end
end

for name, service in loaded do
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn(`[Server] {name}:Init failed: {err}`)
		end
	end
end

for name, service in loaded do
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(`[Server] {name}:Start failed: {err}`)
			end
		end)
	end
end
