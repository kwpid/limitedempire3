-- this play session, for Stats for Nerds: when it started and the player's cash and stats once their data loaded,
-- so the page can show what changed since joining.
-- api: Session.start(), Session.get() -> { startedAt, cash?, stats? } (cash / stats are nil until data loads)

local PlayerState = require(script.Parent.PlayerState)

local Session = {}

local session = { startedAt = os.clock(), cash = nil, stats = nil }

function Session.get()
	return session
end

function Session.start()
	local function snapshot(state)
		if session.cash == nil and PlayerState.isLoaded() then
			session.cash = state.cash
			session.stats = table.clone(state.stats or {})
		end
	end
	snapshot(PlayerState.get())
	PlayerState.changed:Connect(snapshot)
end

return Session
