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
	series: string?,
	originalOwner: OriginalOwner?,
	tracker: StatTracker?,
}

-- who first unboxed the item. stays with the item through trades.
export type OriginalOwner = {
	userId: number,
	name: string,
}

-- rare stat tracker, counts cases opened while the item is equipped.
export type StatTracker = {
	opens: number,
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
