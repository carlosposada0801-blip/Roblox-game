--[[
	CosmeticConfig
	Trails (follow your character) and gate accent colors (recolor your
	factory's neon). Price = cash to buy; Achievement = unlocked by that
	achievement instead. Titles come from AchievementConfig.
]]

return {
	Trails = {
		{ Id = "TrailCyan", Name = "Cyan Streak", Color = Color3.fromRGB(0, 220, 255), Price = 50000 },
		{ Id = "TrailFire", Name = "Fire Trail", Color = Color3.fromRGB(255, 120, 20), Price = 250000 },
		{ Id = "TrailToxic", Name = "Toxic Trail", Color = Color3.fromRGB(80, 255, 80), Price = 1000000 },
		{ Id = "TrailGold", Name = "Golden Trail", Color = Color3.fromRGB(255, 210, 50), Achievement = "Millionaire" },
		{ Id = "TrailVoid", Name = "Void Trail", Color = Color3.fromRGB(140, 40, 255), Achievement = "Ascended" },
		{ Id = "TrailBlood", Name = "Warlord Trail", Color = Color3.fromRGB(230, 30, 40), Achievement = "KO100" },
	},
	Accents = {
		{ Id = "AccentPink", Name = "Hot Pink", Color = Color3.fromRGB(255, 60, 200), Price = 25000 },
		{ Id = "AccentLime", Name = "Lime", Color = Color3.fromRGB(150, 255, 40), Price = 25000 },
		{ Id = "AccentWhite", Name = "Pure White", Color = Color3.fromRGB(255, 255, 255), Price = 100000 },
		{ Id = "AccentRed", Name = "Crimson", Color = Color3.fromRGB(255, 30, 50), Price = 100000 },
		{ Id = "AccentGold", Name = "Gold", Color = Color3.fromRGB(255, 200, 40), Achievement = "Rebirth10" },
	},
}
