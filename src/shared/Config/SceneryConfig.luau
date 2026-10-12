--[[
	SceneryConfig
	Sky, lighting, the world around the plots, and the speedy walkway.
	SceneryService builds it all when the server starts.

	Layout (world space, top view):
	  - Plots sit in two rows on either side of the central aisle (z = -30..30).
	  - The speedy walkway runs down the middle of the aisle (two lanes, opposite directions).
	  - Everything inside ClearZone stays flat; hills, trees and rocks go outside it,
	    with lakes in front of and behind the plots and a ring of mountains far out.
]]

local SceneryConfig = {}

SceneryConfig.Seed = 2026 -- change for a different random layout of trees/hills/mountains

-- Sky & lighting -------------------------------------------------------------

SceneryConfig.Lighting = {
	ClockTime = 16.8, -- starting time of day (golden hour)
	Brightness = 3,
	ExposureCompensation = 0.15,
	Ambient = Color3.fromRGB(70, 60, 90),
	OutdoorAmbient = Color3.fromRGB(120, 110, 150),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	GeographicLatitude = 30,
	ShadowSoftness = 0.25,
}

-- Day/night cycle (runs on each client, synced to server time so everyone matches)
SceneryConfig.DayNight = {
	Enabled = true,
	DayLengthMinutes = 16, -- one full 24h cycle
}

SceneryConfig.Atmosphere = {
	Density = 0.3,
	Offset = 0.2,
	Color = Color3.fromRGB(255, 190, 220), -- pink/peach haze
	Decay = Color3.fromRGB(110, 90, 170), -- purple horizon
	Glare = 0.5,
	Haze = 1.8,
}

SceneryConfig.Sky = {
	StarCount = 5000,
	SunAngularSize = 16,
	MoonAngularSize = 12,
	-- Optional custom skybox: paste 6 image IDs from the Creator Store (search "skybox"),
	-- e.g. Skybox = { Bk = "rbxassetid://123", Dn = "...", Ft = "...", Lf = "...", Rt = "...", Up = "..." }
	Skybox = nil,
}

SceneryConfig.Clouds = {
	Cover = 0.55,
	Density = 0.55,
	Color = Color3.fromRGB(255, 225, 240),
}

SceneryConfig.Bloom = { Intensity = 0.7, Size = 30, Threshold = 1.4 }
SceneryConfig.SunRays = { Intensity = 0.07, Spread = 0.8 }
SceneryConfig.ColorCorrection = {
	Saturation = 0.18,
	Contrast = 0.08,
	Brightness = 0.02,
	TintColor = Color3.fromRGB(255, 247, 240),
}

-- World ----------------------------------------------------------------------

SceneryConfig.World = {
	GroundSize = 2048, -- terrain grass square, centered on the map (multiple of 4)
	-- Half-size (X, Z) of the flat area around the plots and lobby. This area is a solid
	-- grass platform (a part, top at y = 0) with NO terrain, so terrain can never cover
	-- the plots. The terrain scenery around it sits a little lower (TerrainHeight).
	ClearZone = Vector2.new(232, 192),
	TerrainHeight = -4,
	PlatformColor = Color3.fromRGB(92, 152, 74),

	Mountains = { Count = 36, MinDistance = 580, MaxDistance = 820, MinRadius = 90, MaxRadius = 180 },
	Hills = { Count = 50, MaxDistance = 520, MinRadius = 22, MaxRadius = 55 },
	Trees = { Count = 160, MaxDistance = 500 },
	Rocks = { Count = 45, MaxDistance = 500 },

	-- Lakes: center (world) and size (X, depth, Z)
	Lakes = {
		{ Center = Vector3.new(0, 0, 290), Size = Vector3.new(200, 8, 80) },
		{ Center = Vector3.new(0, 0, -290), Size = Vector3.new(200, 8, 80) },
	},
	WaterColor = Color3.fromRGB(40, 140, 200),

	-- Industrial skyline: factory buildings with smokestacks around the map
	Skyline = { Count = 24, MinDistance = 280, MaxDistance = 460 },

	-- Paved aisle between the two rows of plots
	Plaza = { Size = Vector3.new(420, 0.2, 60), Color = Color3.fromRGB(58, 62, 74) },
	StreetLamps = { Spacing = 40, Z = 27 },
}

-- Speedy walkway -------------------------------------------------------------

SceneryConfig.Walkway = {
	Length = 340,
	LaneWidth = 8,
	Height = 0.4,
	Speed = 32, -- studs per second (normal walking is 16)
	Lanes = {
		{ Z = -5, Direction = 1, Color = Color3.fromRGB(0, 200, 255) }, -- toward +X
		{ Z = 5, Direction = -1, Color = Color3.fromRGB(255, 150, 0) }, -- toward -X
	},
	ChevronSpacing = 6, -- distance between the moving arrows
}

-- Music ----------------------------------------------------------------------
-- Two kinds of music:
--  1. Tracks: real songs as { Id = 1234567890, Name = "Song name" }. See README "Adding music".
--     Only use audio you're allowed to use: tracks uploaded by Roblox in the Creator Store
--     (licensed for Roblox experiences) or audio you uploaded yourself.
--  2. Songs: the game's own original soundtrack, played live note by note from
--     sounds built into Roblox (no uploads, no IDs, no copyright). These play
--     whenever Tracks is empty or none of its tracks load.
--
-- Song format: Tempo (beats per minute), Chords (one per bar, looping), and patterns.
--   Chords: { Root = semitones above A (A=0, C=3, D=5, E=7, F=8, G=10), Minor = bool }
--   Arp: which chord notes the lead plays on each 8th note (1 = root, 3 = third,
--        5 = fifth, 8 = octave, 10 = octave + third, 0 = rest)
--   Melody (optional): one entry per 8th note across the whole loop, as semitones
--        above A (false = rest); played an octave above the arpeggio
--   Kick / Snare / Hat: 16th-note steps (0 to 15) in each bar where the drum hits
SceneryConfig.Music = {
	Volume = 0.35,
	Shuffle = true,
	FadeTime = 2,
	Tracks = {
		-- { Id = 0000000000, Name = "Example" },
	},

	SongBars = 32, -- each original song plays this many bars before the next one
	Songs = {
		{
			Name = "Assembly Line",
			Tempo = 118,
			Chords = { { Root = 0, Minor = true }, { Root = 8 }, { Root = 3 }, { Root = 10 } }, -- Am F C G
			Arp = { 1, 5, 8, 5, 3, 5, 8, 10 },
			Melody = {
				12, false, 15, false, 19, 17, 15, false, -- bar 1
				12, false, 15, 17, 15, false, 12, false, -- bar 2
				10, false, 12, false, 15, 12, 10, false, -- bar 3
				7, false, 10, false, 14, false, false, false, -- bar 4
			},
			Kick = { 0, 4, 8, 12 },
			Snare = { 4, 12 },
			Hat = { 2, 6, 10, 14 },
		},
		{
			Name = "Neon Night Shift",
			Tempo = 124,
			Chords = { { Root = 3 }, { Root = 10 }, { Root = 0, Minor = true }, { Root = 8 } }, -- C G Am F
			Arp = { 1, 8, 5, 8, 3, 8, 5, 8 },
			Kick = { 0, 3, 8, 11 },
			Snare = { 4, 12 },
			Hat = { 0, 2, 4, 6, 8, 10, 12, 14 },
		},
		{
			Name = "Sky Cruise",
			Tempo = 100,
			Chords = { { Root = 8 }, { Root = 10 }, { Root = 7, Minor = true }, { Root = 0, Minor = true } }, -- F G Em Am
			Arp = { 1, 3, 5, 8, 10, 8, 5, 3 },
			Melody = {
				20, false, false, 19, 17, false, 15, false,
				22, false, false, 20, 19, false, 17, false,
				19, false, 17, false, 15, false, 14, false,
				12, false, false, false, false, false, false, false,
			},
			Kick = { 0, 10 },
			Snare = { 8 },
			Hat = { 4, 12 },
		},
		{
			Name = "Robot Rush",
			Tempo = 136,
			Chords = { { Root = 5, Minor = true }, { Root = 5, Minor = true }, { Root = 1 }, { Root = 3 } }, -- Dm Dm Bb C
			Arp = { 1, 1, 8, 1, 5, 1, 8, 5 },
			Kick = { 0, 4, 8, 12 },
			Snare = { 4, 12, 14 },
			Hat = { 2, 6, 10, 14 },
		},
	},

	-- Instruments: sounds that ship with Roblox, re-pitched (PlaybackSpeed)
	Instruments = {
		Lead = { Sound = "rbxasset://sounds/volume_slider.ogg", Pitch = 1, Volume = 0.55 },
		Bass = { Sound = "rbxasset://sounds/volume_slider.ogg", Pitch = 0.5, Volume = 0.9 },
		Kick = { Sound = "rbxasset://sounds/action_jump_land.mp3", Pitch = 0.7, Volume = 1 },
		Snare = { Sound = "rbxasset://sounds/impact_water.mp3", Pitch = 2.2, Volume = 0.35, Length = 0.12 },
		Hat = { Sound = "rbxasset://sounds/volume_slider.ogg", Pitch = 3.2, Volume = 0.25 },
	},
}

return SceneryConfig
