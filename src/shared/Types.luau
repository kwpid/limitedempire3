-- shared luau types used across server and client.
-- usage: local Types = require(Shared.Types) then Types.ItemInstance etc.

export type ItemInstance = {
	uid: string,
	assetId: number,
	float: number,
	serial: number,
	trait: string?, -- the best trait, kept so older code and saves keep working
	traits: { string }?, -- every trait best first (stacked traits), read through Traits.of(item)
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

-- rare stat tracker, counts cases opened while the item is equipped. belongs to the item, not the owner, so it
-- carries over through trades. the count is for show only, value uses whether the item has one.
export type StatTracker = {
	opens: number,
}

export type PlayerState = {
	cash: number,
	inventory: { [string]: ItemInstance },
	equipped: { string },
	pinned: { string }, -- uids the player pinned, sorted right after equipped items in the inventory
	settings: { [string]: any }, -- only the values the player changed, read through Settings.resolve
	stats: { [string]: number },
	progress: any, -- { career, season, quests, metrics }, see ProgressService
	version: number,
}

export type Result<T> = {
	ok: boolean,
	err: string?,
	data: T?,
}

return nil
