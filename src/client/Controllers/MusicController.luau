--[[
	MusicController
	Background music from SceneryConfig.Music.Tracks: shuffled playlist,
	fades between songs, skips any track that fails to load, and a
	music on/off button under the side menu. Plays only for this player.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SceneryConfig"))
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Theme = UIKit.Theme
local Music = SceneryConfig.Music

local MusicController = {}

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
	if #tracks == 0 then
		print("[Music] No tracks yet. Add some to SceneryConfig.Music.Tracks (see README).")
		return
	end

	local button
	button = UIKit.button({
		Name = "MusicToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 230),
		Size = UDim2.fromOffset(92, 44),
		Color = Theme.PanelLight,
		Text = "🔊 Music",
		Parent = UIKit.root(),
	}, function()
		muted = not muted
		button.Text = if muted then "🔇 Music" else "🔊 Music"
		if current then
			fade(current, if muted then 0 else Music.Volume)
		end
	end)

	task.spawn(function()
		while true do
			local anyPlayed = false
			for _, track in ipairs(shuffled(tracks)) do
				if playTrack(track) then
					anyPlayed = true
				end
			end
			if not anyPlayed then
				warn("[Music] No tracks could be loaded; music is off.")
				button.Visible = false
				return
			end
		end
	end)
end

return MusicController
