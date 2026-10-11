--[[
	EventConfig
	Server-wide factory events. One starts every Interval seconds (random
	between the two numbers) and lasts Duration seconds. Everyone sees a banner.
]]

return {
	FirstDelay = 90,
	Interval = { 180, 300 },
	Duration = 45,

	Events = {
		GoldenRush = {
			DisplayName = "✨ GOLDEN SCRAP RUSH",
			Description = "Droppers make golden scrap worth 5x!",
			Color = Color3.fromRGB(255, 200, 40),
			GoldenChance = 0.3,
			GoldenMultiplier = 5,
		},
		PowerSurge = {
			DisplayName = "⚡ POWER SURGE",
			Description = "Belts and droppers run at double speed!",
			Color = Color3.fromRGB(0, 200, 255),
			BeltMultiplier = 2,
			DropperMultiplier = 2,
		},
		CashFrenzy = {
			DisplayName = "💰 CASH FRENZY",
			Description = "All cash earned is doubled!",
			Color = Color3.fromRGB(80, 230, 110),
			CashMultiplier = 2,
		},
		RobotParade = {
			DisplayName = "🤖 ROBOT PARADE",
			Description = "Final Assembly builds a robot from every single part!",
			Color = Color3.fromRGB(190, 110, 255),
			PartsPerRobot = 1,
		},
	},
}
