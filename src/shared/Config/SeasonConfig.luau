--[[
	SeasonConfig
	Seasonal events turn on automatically by month (UTC): lobby decorations
	and a limited egg whose pets you keep forever. Force one for testing
	with Override = "Halloween".
]]

return {
	Override = nil,
	Seasons = {
		Halloween = {
			Months = { 10 },
			Name = "🎃 Haunted Factory",
			Color = Color3.fromRGB(255, 120, 20),
			Egg = "PumpkinEgg",
		},
		Winter = {
			Months = { 12, 1 },
			Name = "❄️ Frosty Factory",
			Color = Color3.fromRGB(150, 220, 255),
			Egg = "SnowEgg",
		},
	},
}
