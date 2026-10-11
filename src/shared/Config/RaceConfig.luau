--[[
	RaceConfig
	Robot races on a floating track (portal in the lobby). Enter your race
	bot, it races automatically. Upgrade its speed with robots.
]]

return {
	Center = Vector3.new(0, 400, -420), -- track position (world)
	Length = 260,
	Lanes = 6,
	EntryWindow = 30, -- seconds between races
	BaseSpeed = 30,
	SpeedPerLevel = 2.5,
	RandomSpeed = 6, -- +/- random wobble so races are exciting
	MaxLevel = 20,
	UpgradeCost = function(level)
		return 5 + level * 3 -- robots
	end,
	Prizes = { 30000, 15000, 7500 }, -- 1st/2nd/3rd, x rebirth multiplier
	LobbyPortal = Vector3.new(-120, 0, -20),
}
