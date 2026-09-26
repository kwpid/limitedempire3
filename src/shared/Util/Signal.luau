-- tiny signal class for in-process events (not networked).
-- api: Signal.new(), signal:Connect(fn) -> connection with :Disconnect(), signal:Fire(...), signal:Once(fn)

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local handlers = self._handlers
	local connection = {}
	handlers[connection] = fn
	function connection.Disconnect()
		handlers[connection] = nil
	end
	return connection :: any
end

function Signal:Once(fn: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

return Signal
