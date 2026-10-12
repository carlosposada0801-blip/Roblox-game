--[[
	MusicSynth
	Plays the game's original soundtrack (SceneryConfig.Music.Songs) live,
	note by note, using sounds that ship with Roblox (re-pitched). Nothing to
	upload and no copyright issues. Each instrument keeps a small pool of
	Sound objects that are reused, so it creates no new instances while playing.

	MusicSynth.play(song, bars, getVolume) plays `bars` bars, then returns.
	getVolume() returns the current master volume (0 when muted), so muting
	takes effect on the very next note.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SceneryConfig"))

local Instruments = SceneryConfig.Music.Instruments

local MusicSynth = {}

local POOL_SIZE = 4
local pools = {} -- [instrumentName] = { Sounds = { Sound }, Next = number }
local folder

local function pool(name)
	local entry = pools[name]
	if entry then
		return entry
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Soundtrack"
		folder.Parent = SoundService
	end
	entry = { Sounds = {}, Next = 1 }
	for index = 1, POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = name .. index
		sound.SoundId = Instruments[name].Sound
		sound.Parent = folder
		table.insert(entry.Sounds, sound)
	end
	pools[name] = entry
	return entry
end

-- Semitones -> PlaybackSpeed (12 semitones = one octave = double speed)
local function speedFor(semitones)
	return 2 ^ (semitones / 12)
end

local function playNote(name, semitones, volume)
	local instrument = Instruments[name]
	if volume <= 0 then
		return
	end
	local entry = pool(name)
	local sound = entry.Sounds[entry.Next]
	entry.Next = entry.Next % POOL_SIZE + 1
	sound.PlaybackSpeed = instrument.Pitch * speedFor(semitones or 0)
	sound.Volume = instrument.Volume * volume
	sound.TimePosition = 0
	sound:Play()
	if instrument.Length then
		task.delay(instrument.Length, function()
			if sound.IsPlaying then
				sound:Stop()
			end
		end)
	end
end

-- Chord tone for an Arp number (1 root, 3 third, 5 fifth, 8 octave, 10 octave + third)
local function chordTone(chord, degree)
	local third = if chord.Minor then 3 else 4
	if degree == 1 then
		return chord.Root
	elseif degree == 3 then
		return chord.Root + third
	elseif degree == 5 then
		return chord.Root + 7
	elseif degree == 8 then
		return chord.Root + 12
	elseif degree == 10 then
		return chord.Root + 12 + third
	end
	return nil
end

function MusicSynth.play(song, bars: number, getVolume)
	local stepTime = 60 / song.Tempo / 4 -- one 16th note
	local loopBars = #song.Chords
	local start = os.clock()
	local totalSteps = bars * 16

	for step = 0, totalSteps - 1 do
		-- Wait until this step's time (stays in sync even if a frame is late)
		local due = start + step * stepTime
		local now = os.clock()
		if due > now then
			task.wait(due - now)
		end

		local volume = getVolume()
		local bar = step // 16
		local inBar = step % 16
		local chord = song.Chords[bar % loopBars + 1]

		if table.find(song.Kick, inBar) then
			playNote("Kick", 0, volume)
		end
		if table.find(song.Snare, inBar) then
			playNote("Snare", 0, volume)
		end
		if table.find(song.Hat, inBar) then
			playNote("Hat", 0, volume)
		end

		if inBar % 2 == 0 then
			local eighth = inBar // 2
			-- Bass: root on beats 1 and 3, fifth on the "and" of 2
			if eighth == 0 or eighth == 4 then
				playNote("Bass", chord.Root - 12, volume)
			elseif eighth == 3 then
				playNote("Bass", chord.Root - 5, volume)
			end
			-- Arpeggio
			local tone = chordTone(chord, song.Arp[eighth + 1])
			if tone then
				playNote("Lead", tone, volume * 0.7)
			end
			-- Melody (one 8th note per entry, looping over the chord loop; already an octave up)
			if song.Melody then
				local index = (bar % loopBars) * 8 + eighth + 1
				local note = song.Melody[index]
				if note then
					playNote("Lead", note, volume)
				end
			end
		end
	end
end

return MusicSynth
