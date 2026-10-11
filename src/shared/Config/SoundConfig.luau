--[[
	SoundConfig
	Sound effects. By default every effect is built from Roblox's built-in
	click sound (ships with Roblox, so no upload or copyright issues), played
	at different pitches to make short jingles.

	Each sound is a list of notes: { Pitch = playback speed, Delay = seconds after start }.
	To use your own sound instead, set Id, e.g. Purchase = { Id = "rbxassetid://123" }.
]]

local SoundConfig = {}

SoundConfig.BaseSound = "rbxasset://sounds/volume_slider.ogg"
SoundConfig.Volume = 0.6

SoundConfig.Sounds = {
	-- Any menu button
	Click = { Notes = { { Pitch = 1.3 } } },

	-- Stepping on a buy button you can afford: rising three-note chime
	Purchase = {
		Notes = { { Pitch = 1.4 }, { Pitch = 1.8, Delay = 0.07 }, { Pitch = 2.3, Delay = 0.14 } },
	},

	-- Stepping on a buy button you can't afford: low double buzz
	Denied = { Notes = { { Pitch = 0.55 }, { Pitch = 0.45, Delay = 0.09 } } },

	-- Collecting cash from the pad: quick "cha-ching"
	Cash = { Notes = { { Pitch = 2 }, { Pitch = 2.6, Delay = 0.05 }, { Pitch = 2.6, Delay = 0.1 } } },

	-- Random event starting: siren (up-down twice)
	Event = {
		Notes = {
			{ Pitch = 1.6 },
			{ Pitch = 2.2, Delay = 0.15 },
			{ Pitch = 1.6, Delay = 0.3 },
			{ Pitch = 2.2, Delay = 0.45 },
			{ Pitch = 2.8, Delay = 0.6 },
		},
	},

	-- Countdown tick (boss raid, battles)
	Tick = { Notes = { { Pitch = 2.4 } } },

	-- Rebirth: long rising arpeggio
	Rebirth = {
		Notes = {
			{ Pitch = 1 },
			{ Pitch = 1.25, Delay = 0.08 },
			{ Pitch = 1.5, Delay = 0.16 },
			{ Pitch = 2, Delay = 0.24 },
			{ Pitch = 2.5, Delay = 0.32 },
			{ Pitch = 3, Delay = 0.4 },
		},
	},
}

return SoundConfig
