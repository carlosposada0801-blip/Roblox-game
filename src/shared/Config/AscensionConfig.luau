--[[
	AscensionConfig
	Prestige: once you have RequiredRebirths, you can Ascend. It resets
	rebirths, cash and your factory, and gives a permanent x Multiplier per
	ascension (stacks) plus a new factory theme.
]]

return {
	RequiredRebirths = 10,
	MultiplierPerAscension = 2, -- x2, x4, x8 ...
	Themes = {
		[0] = { Name = "Industrial", Base = Color3.fromRGB(46, 50, 60), Material = Enum.Material.DiamondPlate, Accent = nil },
		[1] = { Name = "Space Station", Base = Color3.fromRGB(30, 26, 50), Material = Enum.Material.Metal, Accent = Color3.fromRGB(120, 200, 255) },
		[2] = { Name = "Underwater Lab", Base = Color3.fromRGB(20, 60, 70), Material = Enum.Material.Glass, Accent = Color3.fromRGB(0, 255, 210) },
		[3] = { Name = "Volcano Forge", Base = Color3.fromRGB(35, 20, 18), Material = Enum.Material.Basalt, Accent = Color3.fromRGB(255, 90, 20) },
	},
}
