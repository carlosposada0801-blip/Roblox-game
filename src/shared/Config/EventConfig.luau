--[[
	EventConfig
	Random server-wide events. One starts every Interval seconds (random
	between the two numbers) while players are online, and lasts its own
	Duration. Everyone sees a banner with a countdown and hears a siren.

	Effect keys other services read (EventService:GetValue):
	  BeltMultiplier, DropperMultiplier   speed (Power Surge)
	  GoldenChance, GoldenMultiplier      golden parts worth more (Golden Rain)
	  CashMultiplier                      all cash earned
	  PartsPerRobot                       Final Assembly parts per robot
	  Malfunction = { ... }               a machine in every factory breaks (see below)
]]

return {
	FirstDelay = 120,
	Interval = { 600, 1200 }, -- 10 to 20 minutes between events

	Events = {
		PowerSurge = {
			DisplayName = "⚡ POWER SURGE",
			Description = "Belts and droppers run at TRIPLE speed!",
			Color = Color3.fromRGB(0, 200, 255),
			Duration = 30,
			BeltMultiplier = 3,
			DropperMultiplier = 3,
		},
		GoldenRain = {
			DisplayName = "✨ GOLDEN RAIN",
			Description = "Droppers make golden parts worth 10x!",
			Color = Color3.fromRGB(255, 200, 40),
			Duration = 20,
			GoldenChance = 0.5,
			GoldenMultiplier = 10,
		},
		Malfunction = {
			DisplayName = "🔧 MALFUNCTION!",
			Description = "A machine in your factory is sparking! Click it fast to fix it!",
			Color = Color3.fromRGB(255, 90, 40),
			Duration = 25,
			Malfunction = {
				ClicksToFix = 15,
				BrokenValueMultiplier = 0.5, -- the broken machine adds half value until fixed
				RewardCash = 5000, -- x rebirth multiplier, for fixing it in time
			},
		},
		CashFrenzy = {
			DisplayName = "💰 CASH FRENZY",
			Description = "All cash earned is doubled!",
			Color = Color3.fromRGB(80, 230, 110),
			Duration = 45,
			CashMultiplier = 2,
		},
		RobotParade = {
			DisplayName = "🤖 ROBOT PARADE",
			Description = "Final Assembly builds a robot from every single part!",
			Color = Color3.fromRGB(190, 110, 255),
			Duration = 45,
			PartsPerRobot = 1,
		},
	},
}
