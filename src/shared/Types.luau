-- shared luau types used across server and client.
-- usage: local Types = require(Shared.Types) then Types.ItemInstance etc.

export type ItemInstance = {
	uid: string,
	assetId: number,
	float: number,
	serial: number,
	trait: string?,
	caseId: string?,
	obtainedAt: number,
}

export type PlayerState = {
	cash: number,
	inventory: { [string]: ItemInstance },
	equipped: { string },
	version: number,
}

export type Result<T> = {
	ok: boolean,
	err: string?,
	data: T?,
}

return nil
