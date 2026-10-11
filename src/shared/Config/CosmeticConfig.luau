--[[
	CosmeticConfig
	Trails (follow your character), gate accent colors (recolor your
	factory's neon) and robot skins (recolor every robot your factory builds).
	Price = cash to buy; Achievement = unlocked by that achievement instead;
	Exclusive = only given by that source (StarterPack, Boss, Weekly, Code).
	Tradable = true lets players trade it (TradeService).
	Titles come from AchievementConfig (and weekly leaderboard prizes).
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
	Skins = {
		{ Id = "SkinChrome", Name = "Chrome", Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Foil, Price = 75000 },
		{ Id = "SkinCamo", Name = "Jungle Camo", Color = Color3.fromRGB(70, 110, 60), Material = Enum.Material.Fabric, Price = 300000 },
		{ Id = "SkinNeon", Name = "Neon Pulse", Color = Color3.fromRGB(0, 255, 200), Material = Enum.Material.Neon, Price = 2000000 },
		{ Id = "SkinStarter", Name = "Founder Gold", Color = Color3.fromRGB(255, 190, 40), Material = Enum.Material.Foil, Glow = true, Exclusive = "StarterPack" },
		{ Id = "SkinOmega", Name = "Omega Destroyer", Color = Color3.fromRGB(200, 20, 40), Material = Enum.Material.Neon, Glow = true, Exclusive = "Boss", Tradable = true },
		{ Id = "SkinChampion", Name = "Weekly Champion", Color = Color3.fromRGB(150, 80, 255), Material = Enum.Material.Glass, Glow = true, Exclusive = "Weekly", Tradable = true },
		{ Id = "SkinRelease", Name = "Launch Day", Color = Color3.fromRGB(255, 100, 180), Material = Enum.Material.SmoothPlastic, Exclusive = "Code", Tradable = true },
	},
}
