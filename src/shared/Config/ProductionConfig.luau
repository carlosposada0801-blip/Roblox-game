--[[
	ProductionConfig
	How dropped items behave: belt speed, lag limits, item looks per stage,
	and the Prototype robot roll.

	Stages flow:  Scrap -> Metal (Smelter) -> RobotPart (Assembler) -> Robot (Final Assembly)
	The Painter adds color + value to any stage before Robot.
]]

local ProductionConfig = {}

ProductionConfig.BeltSpeed = 8 -- studs/second before conveyor upgrades and passes
ProductionConfig.MaxDropsPerPlot = 60 -- droppers pause while a plot has this many items
ProductionConfig.DropLifetime = 90 -- seconds before a stuck item is cleaned up (Debris)
ProductionConfig.CashPadCooldown = 0.5

-- Prototype robots: rare special robots usable in the PvP arena
ProductionConfig.PrototypeChance = 0.01 -- 1% of robots built
ProductionConfig.PrototypeValueMultiplier = 10

ProductionConfig.Stages = {
	Scrap = {
		Size = Vector3.new(1, 1, 1),
		Color = Color3.fromRGB(120, 95, 75),
		Material = Enum.Material.CorrodedMetal,
	},
	Metal = {
		Size = Vector3.new(1.6, 0.7, 1),
		Color = Color3.fromRGB(200, 205, 215),
		Material = Enum.Material.Metal,
	},
	RobotPart = {
		Size = Vector3.new(1.3, 1.3, 1.3),
		Color = Color3.fromRGB(70, 120, 200),
		Material = Enum.Material.DiamondPlate,
	},
	Robot = {
		Size = Vector3.new(1.6, 1.8, 1.2), -- body; a head and eyes are added on top
		Color = Color3.fromRGB(160, 165, 175),
		Material = Enum.Material.Metal,
	},
}

-- Random colors the Painter can apply
ProductionConfig.PaintColors = {
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(255, 170, 0),
	Color3.fromRGB(255, 240, 60),
	Color3.fromRGB(60, 220, 100),
	Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(170, 85, 255),
	Color3.fromRGB(255, 100, 200),
}

return ProductionConfig
