--[[
	Sfx
	Plays a sound effect from SoundConfig for this player only.
	Sfx.play("Purchase")
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))

local Sfx = {}

local function playOnce(soundId, pitch, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

function Sfx.play(name: string)
	local definition = SoundConfig.Sounds[name]
	if not definition then
		return
	end

	local volume = definition.Volume or SoundConfig.Volume
	if definition.Id then
		playOnce(definition.Id, definition.Pitch, volume)
		return
	end

	for _, note in ipairs(definition.Notes or {}) do
		if note.Delay and note.Delay > 0 then
			task.delay(note.Delay, playOnce, SoundConfig.BaseSound, note.Pitch, volume)
		else
			playOnce(SoundConfig.BaseSound, note.Pitch, volume)
		end
	end
end

return Sfx
