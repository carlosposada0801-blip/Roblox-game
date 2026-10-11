--[[
	RarityConfig
	Every robot rolls a rarity when it's built. Rarer robots are worth more
	and look flashier. Each new rarity + color combination you sell is added
	to your Robot Collection Book, and every entry gives a permanent cash bonus.
]]

return {
	Rarities = {
		{ Id = "Common", Weight = 60, ValueMultiplier = 1, Color = Color3.fromRGB(190, 195, 205) },
		{ Id = "Uncommon", Weight = 25, ValueMultiplier = 1.5, Color = Color3.fromRGB(90, 230, 110) },
		{ Id = "Rare", Weight = 10, ValueMultiplier = 2.5, Color = Color3.fromRGB(60, 160, 255) },
		{ Id = "Epic", Weight = 4, ValueMultiplier = 5, Color = Color3.fromRGB(190, 90, 255) },
		{ Id = "Legendary", Weight = 1, ValueMultiplier = 10, Color = Color3.fromRGB(255, 200, 40) },
	},
	-- Robot body colors in the book (Steel = never painted). Names match ProductionConfig.PaintColors.
	Colors = { "Steel", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink" },
	BonusPerEntry = 0.01, -- +1% cash per book entry discovered
}
