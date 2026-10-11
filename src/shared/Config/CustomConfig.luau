--[[
	CustomConfig
	Factory customization (Customize window, CustomizationService).
	  Walls    recolor every wall item (Category = "Wall")
	  Machines recolor the body of every machine
	  Floors   change your plot floor's material and color
	  Sign     a neon sign over your gate with your own text (filtered by Roblox)
	  Decor    decorations you place on DecorSlots around your plot

	Price = 0 is free, a number is cash. VIP = true needs Roblox Premium or
	the VIP Floor game pass. Everything is saved and rebuilt when you rejoin.
	Ids must be unique across every list.
]]

local CustomConfig = {}

CustomConfig.SignMaxLength = 24
CustomConfig.SignColor = Color3.fromRGB(255, 80, 200)

CustomConfig.Walls = {
	{ Id = "WallSteel", Name = "Steel Grey", Color = Color3.fromRGB(120, 125, 135), Price = 0 },
	{ Id = "WallNavy", Name = "Navy", Color = Color3.fromRGB(30, 45, 90), Price = 0 },
	{ Id = "WallBrick", Name = "Brick Red", Color = Color3.fromRGB(150, 60, 45), Price = 15000 },
	{ Id = "WallMint", Name = "Mint", Color = Color3.fromRGB(110, 220, 170), Price = 40000 },
	{ Id = "WallBlack", Name = "Stealth Black", Color = Color3.fromRGB(25, 25, 30), Price = 150000 },
	{ Id = "WallGold", Name = "Gold Plated", Color = Color3.fromRGB(230, 180, 50), VIP = true },
}

CustomConfig.Machines = {
	{ Id = "MachineOrange", Name = "Safety Orange", Color = Color3.fromRGB(255, 130, 30), Price = 0 },
	{ Id = "MachineWhite", Name = "Lab White", Color = Color3.fromRGB(235, 238, 245), Price = 0 },
	{ Id = "MachineTeal", Name = "Teal", Color = Color3.fromRGB(0, 160, 160), Price = 20000 },
	{ Id = "MachinePurple", Name = "Royal Purple", Color = Color3.fromRGB(110, 50, 200), Price = 75000 },
	{ Id = "MachineRainbow", Name = "Chrome", Color = Color3.fromRGB(200, 205, 215), Price = 300000 },
	{ Id = "MachineDiamond", Name = "Diamond Blue", Color = Color3.fromRGB(120, 220, 255), VIP = true },
}

CustomConfig.Floors = {
	{ Id = "FloorPlate", Name = "Diamond Plate", Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(46, 50, 60), Price = 0 },
	{ Id = "FloorConcrete", Name = "Concrete", Material = Enum.Material.Concrete, Color = Color3.fromRGB(110, 110, 110), Price = 0 },
	{ Id = "FloorWood", Name = "Wood Planks", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 100, 60), Price = 25000 },
	{ Id = "FloorMarble", Name = "Marble", Material = Enum.Material.Marble, Color = Color3.fromRGB(220, 220, 225), Price = 100000 },
	{ Id = "FloorNeon", Name = "Neon Grid", Material = Enum.Material.Glass, Color = Color3.fromRGB(30, 10, 60), Price = 400000 },
	{ Id = "FloorGold", Name = "Golden Floor", Material = Enum.Material.Foil, Color = Color3.fromRGB(230, 180, 50), VIP = true },
}

-- Plot-local positions (floor level) where decorations can go
CustomConfig.DecorSlots = {
	Vector3.new(-44, 0, 44),
	Vector3.new(-36, 0, 44),
	Vector3.new(36, 0, 44),
	Vector3.new(44, 0, 44),
	Vector3.new(-46, 0, 20),
	Vector3.new(46, 0, 20),
}

CustomConfig.Decor = {
	{ Id = "DecorPlant", Name = "Potted Plant", Kind = "Plant", Price = 0 },
	{ Id = "DecorCrates", Name = "Crate Stack", Kind = "Crates", Price = 0 },
	{ Id = "DecorFlag", Name = "Factory Flag", Kind = "Flag", Price = 5000 },
	{ Id = "DecorLamp", Name = "Lava Lamp", Kind = "LavaLamp", Price = 20000 },
	{ Id = "DecorFountain", Name = "Neon Fountain", Kind = "Fountain", Price = 60000 },
	{ Id = "DecorStatue", Name = "Mini Robot Statue", Kind = "Statue", Price = 150000 },
	{ Id = "DecorHologram", Name = "Hologram Ring", Kind = "Hologram", Price = 500000 },
	{ Id = "DecorGoldGear", Name = "Golden Gear", Kind = "GoldGear", VIP = true },
}

return CustomConfig
