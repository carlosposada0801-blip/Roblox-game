--[[
	PetConfig
	Drone pets hatch from eggs bought with cash. Equipped pets follow you and
	add their Bonus to your cash multiplier (0.1 = +10%).
]]

return {
	MaxEquipped = 3,
	MaxInventory = 30,

	Eggs = {
		{
			Id = "ScrapEgg",
			DisplayName = "Scrap Egg",
			Icon = "🥚",
			Price = 15000,
			Color = Color3.fromRGB(160, 120, 80),
			Pets = { { Pet = "Bolt", Weight = 50 }, { Pet = "Gear", Weight = 32 }, { Pet = "Spark", Weight = 14 }, { Pet = "Nova", Weight = 4 } },
		},
		{
			Id = "NeonEgg",
			DisplayName = "Neon Egg",
			Icon = "💠",
			Price = 250000,
			Color = Color3.fromRGB(0, 220, 255),
			Pets = { { Pet = "Spark", Weight = 40 }, { Pet = "Nova", Weight = 30 }, { Pet = "Pulse", Weight = 20 }, { Pet = "Omega", Weight = 9 }, { Pet = "Celestia", Weight = 1 } },
		},
		{
			Id = "GalaxyEgg",
			DisplayName = "Galaxy Egg",
			Icon = "🌌",
			Price = 2500000,
			Color = Color3.fromRGB(150, 70, 255),
			Pets = { { Pet = "Nova", Weight = 35 }, { Pet = "Pulse", Weight = 30 }, { Pet = "Omega", Weight = 22 }, { Pet = "Celestia", Weight = 10 }, { Pet = "Quasar", Weight = 3 } },
		},
	},

	Pets = {
		Bolt = { DisplayName = "Bolt", Rarity = "Common", Bonus = 0.05, Color = Color3.fromRGB(200, 205, 215) },
		Gear = { DisplayName = "Gear", Rarity = "Uncommon", Bonus = 0.1, Color = Color3.fromRGB(90, 230, 110) },
		Spark = { DisplayName = "Spark", Rarity = "Rare", Bonus = 0.2, Color = Color3.fromRGB(60, 160, 255) },
		Nova = { DisplayName = "Nova", Rarity = "Epic", Bonus = 0.35, Color = Color3.fromRGB(190, 90, 255) },
		Pulse = { DisplayName = "Pulse", Rarity = "Epic", Bonus = 0.5, Color = Color3.fromRGB(255, 80, 180) },
		Omega = { DisplayName = "Omega", Rarity = "Legendary", Bonus = 1, Color = Color3.fromRGB(255, 200, 40) },
		Celestia = { DisplayName = "Celestia", Rarity = "Mythic", Bonus = 2, Color = Color3.fromRGB(255, 255, 255) },
		Quasar = { DisplayName = "Quasar", Rarity = "Mythic", Bonus = 3.5, Color = Color3.fromRGB(120, 40, 255) },
	},

	RarityColors = {
		Common = Color3.fromRGB(190, 195, 205),
		Uncommon = Color3.fromRGB(90, 230, 110),
		Rare = Color3.fromRGB(60, 160, 255),
		Epic = Color3.fromRGB(190, 90, 255),
		Legendary = Color3.fromRGB(255, 200, 40),
		Mythic = Color3.fromRGB(255, 90, 90),
	},
}
