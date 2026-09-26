local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local ClientSettings = require(script.Parent.ClientSettings)

local SOUNDS = {
	click = { id = 15675059323, volume = 0.45 },
	tab = { id = 15675032796, volume = 0.5 },
	tick = { id = 15675032796, volume = 0.35, pool = 6 },
	unlock = { id = 9116324157, volume = 0.6 },
	whoosh = { id = 15675024286, volume = 0.5 },
	reveal = { id = 15675085146, volume = 0.6 },
	revealRare = { id = 15675043410, volume = 0.65 },
	revealMythic = { id = 15675043410, volume = 0.8, speed = 0.8 },
	revealMythicSweep = { id = 15674975792, volume = 0.6 },
	sell = { id = 1319346243, volume = 0.55 },
	error = { id = 15675075163, volume = 0.45 },
	equip = { id = 15675046931, volume = 0.5 },
}

local Sfx = {}

local folder: Folder
local pools: { [string]: { Sound } } = {}
local cursors: { [string]: number } = {}

local function build()
	folder = Instance.new("Folder")
	folder.Name = "LimitedEmpireSfx"
	folder.Parent = SoundService

	local preload = {}
	for name, def in SOUNDS do
		local pool = {}
		for i = 1, def.pool or 2 do
			local sound = Instance.new("Sound")
			sound.Name = name .. i
			sound.SoundId = "rbxassetid://" .. def.id
			sound.Volume = def.volume or 0.5
			sound.PlaybackSpeed = def.speed or 1
			sound.Parent = folder
			table.insert(pool, sound)
		end
		pools[name] = pool
		cursors[name] = 0
		table.insert(preload, pool[1])
	end
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, preload)
end

function Sfx.play(name: string, speed: number?)
	local pool = pools[name]
	local volume = ClientSettings.get("sfxVolume") or 1
	if not pool or volume <= 0 then
		return
	end
	local index = cursors[name] % #pool + 1
	cursors[name] = index
	local sound = pool[index]
	sound.PlaybackSpeed = speed or SOUNDS[name].speed or 1
	sound.Volume = (SOUNDS[name].volume or 0.5) * volume
	sound.TimePosition = 0
	sound:Play()
end

function Sfx.start()
	build()
end

return Sfx
