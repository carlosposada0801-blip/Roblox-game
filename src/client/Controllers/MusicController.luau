--[[
	MusicController
	Background music, for this player only:
	  * SceneryConfig.Music.Tracks (real songs): shuffled playlist, fades between
	    songs, skips any track that fails to load.
	  * If there are no tracks (or none load), the game's own original
	    soundtrack (SceneryConfig.Music.Songs), played live by MusicSynth.
	A music on/off button sits under the side menu.
	On/off is saved (Settings > Music, attribute Setting_Music).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SceneryConfig"))
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)
local MusicSynth = require(script.Parent.Parent.MusicSynth)

local Theme = UIKit.Theme
local Music = SceneryConfig.Music

local MusicController = {}

local player = Players.LocalPlayer
local muted = false
local current

local function shuffled(list)
	local copy = table.clone(list)
	if Music.Shuffle then
		for i = #copy, 2, -1 do
			local j = math.random(i)
			copy[i], copy[j] = copy[j], copy[i]
		end
	end
	return copy
end

local function fade(sound, volume)
	local tween = TweenService:Create(sound, TweenInfo.new(Music.FadeTime), { Volume = volume })
	tween:Play()
	return tween
end

-- Plays one track to the end. Returns false if it couldn't load.
local function playTrack(track)
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = "rbxassetid://" .. tostring(track.Id)
	sound.Volume = 0
	sound.Parent = SoundService

	local deadline = os.clock() + 10
	while not sound.IsLoaded and os.clock() < deadline do
		task.wait(0.2)
	end
	if not sound.IsLoaded then
		warn(("[Music] Couldn't load track %s (%s). Check the ID in SceneryConfig."):format(tostring(track.Name), tostring(track.Id)))
		sound:Destroy()
		return false
	end

	current = sound
	sound:Play()
	fade(sound, if muted then 0 else Music.Volume)

	-- Start fading out a little before the end
	local playTime = math.max(0, sound.TimeLength - Music.FadeTime)
	local finished = false
	sound.Ended:Once(function()
		finished = true
	end)
	local started = os.clock()
	while not finished and os.clock() - started < playTime do
		task.wait(0.5)
	end

	fade(sound, 0).Completed:Wait()
	sound:Destroy()
	current = nil
	return true
end

function MusicController:Start()
	local tracks = Music.Tracks
	local button
	button = UIKit.button({
		Name = "MusicToggle",
		AnchorPoint = if UIKit.IsTouch then Vector2.new(0, 0) else Vector2.new(0, 0.5),
		Position = if UIKit.IsTouch then UDim2.new(0, 64, 0, 256) else UDim2.new(0, 66, 0.5, 190),
		Size = UDim2.fromOffset(48, 44),
		Color = Theme.Green,
		Text = "🔊",
		Parent = UIKit.root(),
	}, function()
		Net.Fire("SetSetting", "Music", muted)
	end)

	-- The saved setting decides; the button and the Settings window both change it
	local function applySetting()
		muted = player:GetAttribute("Setting_Music") == false
		button.Text = if muted then "🔇" else "🔊"
		button:SetAttribute("BaseColor", if muted then Theme.Disabled else Theme.Green)
		if current then
			fade(current, if muted then 0 else Music.Volume)
		end
	end
	player:GetAttributeChangedSignal("Setting_Music"):Connect(applySetting)
	applySetting()

	-- The original soundtrack: fades in, follows the mute setting note by note
	local synthVolume = 0
	local function playOriginalSoundtrack()
		local songs = Music.Songs or {}
		if #songs == 0 then
			button.Visible = false
			return
		end
		print("[Music] Playing the original soundtrack.")
		while true do
			for _, song in ipairs(shuffled(songs)) do
				local started = os.clock()
				MusicSynth.play(song, Music.SongBars or 32, function()
					-- Fade in over FadeTime at the start of each song
					local fade = math.clamp((os.clock() - started) / Music.FadeTime, 0, 1)
					synthVolume = if muted then 0 else Music.Volume * 2 * fade
					return synthVolume
				end)
				task.wait(1) -- short breath between songs
			end
		end
	end

	task.spawn(function()
		if #tracks == 0 then
			playOriginalSoundtrack()
			return
		end
		while true do
			local anyPlayed = false
			for _, track in ipairs(shuffled(tracks)) do
				if playTrack(track) then
					anyPlayed = true
				end
			end
			if not anyPlayed then
				warn("[Music] None of the tracks in SceneryConfig.Music.Tracks loaded; playing the original soundtrack instead.")
				playOriginalSoundtrack()
				return
			end
		end
	end)
end

return MusicController
