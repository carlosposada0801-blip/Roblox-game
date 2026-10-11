--[[
	ItemConfig
	Every purchasable tycoon item: its buy button, price, unlock order and looks.
	TycoonService reads this table, so adding an item only means adding an entry.

	Entry fields
	  Id          unique string, also the save key (never rename it once players own it)
	  DisplayName text on the buy button
	  Category    "Dropper" | "Conveyor" | "Collector" | "Machine" | "Wall" | "Floor" | "Decoration"
	  Price       cost in cash (0 = free)
	  Requires    list of Ids that must be owned before this button appears ({} = available from the start)
	  Button      plot-local position of the buy button (keep each one unique)
	  Parts       list of part definitions (see below). Can be skipped if you use a template model.
	  Label       optional: true shows the DisplayName above the built item
	  GamePass    optional: key from MonetizationConfig.GamePasses. The item has no
	              button and is built automatically for owners of that pass.

	Behavior (optional)
	  Dropper   = { Interval = seconds, Value = cash, Stage = "Scrap" }
	  Conveyor  = { SpeedMultiplier = 1.5 }   the fastest owned conveyor item sets the belt speed
	  Machine   = { Accepts = { stages }, Output = stage, Multiplier = n, Paint = bool, PartsPerRobot = n }
	  Collector = {}                          turns items into cash at its "Intake" part

	Part definitions
	  Any Part property works (Size, Color, Material, Transparency, CanCollide, Shape...).
	  CFrame is plot-local: x = left/right, y = up, z = back (-50) to entrance (+50).
	  Light = { Brightness, Range, Color } adds a PointLight.
	  Some part names have special meaning in later steps:
	    "Spout"  where a dropper spawns scrap      (step 3)
	    "Belt"   conveyor surface that moves items (step 3)
	    "Intake" collector sensor                  (step 3)
	    "Zone"   machine sensor that upgrades items (step 4)
	    "CashPad" the pad the owner steps on to collect cash

	Custom models
	  Put a Model named after the item's Id in ServerStorage > TycoonItems and it's
	  used instead of Parts. Set the model's pivot to the plot center (0, 0, 0)
	  in plot-local space, or set Pivot = CFrame.new(...) on the entry.
]]

-- Shared layout numbers -----------------------------------------------------

local BELT_Z = -20 -- the production line runs along X at this depth
local BELT_TOP = 1.7 -- height of the belt surface
local BELT_START, BELT_END = -46, 40

local DARK_METAL = Color3.fromRGB(45, 47, 52)
local STEEL = Color3.fromRGB(140, 145, 155)

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

-- Part list builders (they only return data) -------------------------------

local function dropper(x, color)
	return {
		{ Name = "Body", Size = Vector3.new(5, 4, 10), CFrame = at(x, 11, BELT_Z), Color = color, Material = Enum.Material.Metal },
		{ Name = "Spout", Size = Vector3.new(2.5, 1.5, 2.5), CFrame = at(x, 8.25, BELT_Z), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon },
		{ Name = "Leg", Size = Vector3.new(1, 9, 1), CFrame = at(x, 4.5, BELT_Z - 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Leg", Size = Vector3.new(1, 9, 1), CFrame = at(x, 4.5, BELT_Z + 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
	}
end

local function machine(x, color)
	return {
		{ Name = "Roof", Size = Vector3.new(6, 2, 10.5), CFrame = at(x, 9, BELT_Z), Color = color, Material = Enum.Material.Metal },
		{ Name = "Glow", Size = Vector3.new(6.2, 0.6, 10.7), CFrame = at(x, 8, BELT_Z), Color = color, Material = Enum.Material.Neon },
		{ Name = "Pillar", Size = Vector3.new(6, 8, 1.5), CFrame = at(x, 4, BELT_Z - 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Pillar", Size = Vector3.new(6, 8, 1.5), CFrame = at(x, 4, BELT_Z + 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Zone", Size = Vector3.new(4, 4, 6), CFrame = at(x, BELT_TOP + 2, BELT_Z), Transparency = 1, CanCollide = false, CanQuery = false },
	}
end

-- A motor housing that sits behind the belt
local function motor(x, size, color)
	local z = BELT_Z - 5.5 - size.Z / 2
	return {
		{ Name = "Motor", Size = size, CFrame = at(x, size.Y / 2, z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "MotorLight", Size = Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), CFrame = at(x, size.Y - 0.5, z), Color = color, Material = Enum.Material.Neon },
		{ Name = "Driveshaft", Size = Vector3.new(0.6, 0.6, 3), CFrame = at(x, 1, BELT_Z - 4.5), Color = Color3.fromRGB(140, 145, 155), Material = Enum.Material.Metal },
	}
end

local function lampPost(x, z)
	return {
		{ Name = "Pole", Size = Vector3.new(0.8, 12, 0.8), CFrame = at(x, 6, z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{
			Name = "Lamp",
			Size = Vector3.new(2, 2, 2),
			Shape = Enum.PartType.Ball,
			CFrame = at(x, 12.5, z),
			Color = Color3.fromRGB(255, 240, 200),
			Material = Enum.Material.Neon,
			Light = { Brightness = 2, Range = 24, Color = Color3.fromRGB(255, 230, 190) },
		},
	}
end

local function concat(...)
	local result = {}
	for _, list in ipairs({ ... }) do
		table.move(list, 1, #list, #result + 1, result)
	end
	return result
end

-- Button rows (plot-local Z)
local ROW_PRODUCTION = -8 -- buttons sit right in front of the item they build
local ROW_CONVEYOR = 4
local ROW_BUILDING = 16

-- Items ---------------------------------------------------------------------
-- The order here is just for readability. Unlock order comes from Requires.

local Items = {
	-- Starter set (free) ------------------------------------------------------
	{
		Id = "MainConveyor",
		DisplayName = "Conveyor Belt",
		Category = "Conveyor",
		Price = 0,
		Requires = {},
		Button = Vector3.new(-30, 0, ROW_CONVEYOR),
		Conveyor = { SpeedMultiplier = 1 },
		Parts = {
			{ Name = "Frame", Size = Vector3.new(BELT_END - BELT_START, 1.5, 7), CFrame = at((BELT_START + BELT_END) / 2, 0.75, BELT_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
			{ Name = "Belt", Size = Vector3.new(BELT_END - BELT_START, 0.2, 6), CFrame = at((BELT_START + BELT_END) / 2, BELT_TOP - 0.1, BELT_Z), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Fabric },
			{ Name = "Rail", Size = Vector3.new(BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + BELT_END) / 2, BELT_TOP + 0.5, BELT_Z - 3.25), Color = STEEL, Material = Enum.Material.Metal },
			{ Name = "Rail", Size = Vector3.new(BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + BELT_END) / 2, BELT_TOP + 0.5, BELT_Z + 3.25), Color = STEEL, Material = Enum.Material.Metal },
		},
	},
	{
		Id = "Collector",
		DisplayName = "Collector",
		Category = "Collector",
		Price = 0,
		Requires = { "MainConveyor" },
		Button = Vector3.new(44, 0, ROW_PRODUCTION),
		Label = true,
		Collector = {},
		Parts = {
			{ Name = "Base", Size = Vector3.new(7, 1, 9), CFrame = at(44.5, 0.5, BELT_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
			{ Name = "Wall", Size = Vector3.new(1, 4, 9), CFrame = at(47.5, 3, BELT_Z), Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Metal },
			{ Name = "Wall", Size = Vector3.new(6, 4, 1), CFrame = at(44, 3, BELT_Z - 4), Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Metal },
			{ Name = "Wall", Size = Vector3.new(6, 4, 1), CFrame = at(44, 3, BELT_Z + 4), Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Metal },
			{ Name = "Intake", Size = Vector3.new(6, 3, 7), CFrame = at(44, 2.5, BELT_Z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false },
			{ Name = "CashPadRim", Size = Vector3.new(7, 0.3, 7), CFrame = at(44, 0.15, -6), Color = DARK_METAL, Material = Enum.Material.Metal },
			{ Name = "CashPad", Size = Vector3.new(6, 0.4, 6), CFrame = at(44, 0.35, -6), Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Neon, CanCollide = false },
		},
	},
	{
		Id = "Dropper1",
		DisplayName = "Scrap Dropper",
		Category = "Dropper",
		Price = 0,
		Requires = { "Collector" },
		Button = Vector3.new(-42, 0, ROW_PRODUCTION),
		Dropper = { Interval = 2.5, Value = 4 },
		Parts = dropper(-42, Color3.fromRGB(150, 110, 70)),
	},

	-- Early game --------------------------------------------------------------
	{
		Id = "Dropper2",
		DisplayName = "Scrap Dropper II",
		Category = "Dropper",
		Price = 75,
		Requires = { "Dropper1" },
		Button = Vector3.new(-34, 0, ROW_PRODUCTION),
		Dropper = { Interval = 2.5, Value = 6 },
		Parts = dropper(-34, Color3.fromRGB(150, 110, 70)),
	},
	{
		Id = "FactoryFloor",
		DisplayName = "Factory Floor",
		Category = "Floor",
		Price = 120,
		Requires = { "Dropper2" },
		Button = Vector3.new(-40, 0, ROW_BUILDING),
		Parts = {
			{ Name = "Floor", Size = Vector3.new(98, 0.1, 46), CFrame = at(0, 0.05, -26), Color = Color3.fromRGB(70, 80, 95), Material = Enum.Material.Slate },
		},
	},
	{
		Id = "Smelter",
		DisplayName = "Smelter",
		Category = "Machine",
		Price = 250,
		Requires = { "Dropper2" },
		Button = Vector3.new(-10, 0, ROW_PRODUCTION),
		Label = true,
		Machine = { Accepts = { "Scrap" }, Output = "Metal", Multiplier = 2 },
		Parts = machine(-10, Color3.fromRGB(255, 100, 30)),
	},
	{
		Id = "BackWall",
		DisplayName = "Back Wall",
		Category = "Wall",
		Price = 300,
		Requires = { "Smelter" },
		Button = Vector3.new(-30, 0, ROW_BUILDING),
		Parts = {
			{ Name = "Wall", Size = Vector3.new(100, 14, 1), CFrame = at(0, 7, -49.5), Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.Concrete },
			{ Name = "Stripe", Size = Vector3.new(100, 1, 1.2), CFrame = at(0, 13, -49.5), Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Neon },
		},
	},
	{
		Id = "Dropper3",
		DisplayName = "Heavy Scrap Dropper",
		Category = "Dropper",
		Price = 500,
		Requires = { "Smelter" },
		Button = Vector3.new(-26, 0, ROW_PRODUCTION),
		Dropper = { Interval = 2, Value = 10 },
		Parts = dropper(-26, Color3.fromRGB(110, 120, 135)),
	},
	{
		Id = "ConveyorMk2",
		DisplayName = "Belt Motor Mk2",
		Category = "Conveyor",
		Price = 750,
		Requires = { "Dropper3" },
		Button = Vector3.new(-20, 0, ROW_CONVEYOR),
		Conveyor = { SpeedMultiplier = 1.5 },
		Parts = motor(-38, Vector3.new(5, 4, 4), Color3.fromRGB(0, 170, 255)),
	},

	-- Mid game ----------------------------------------------------------------
	{
		Id = "Assembler",
		DisplayName = "Assembler",
		Category = "Machine",
		Price = 1200,
		Requires = { "Dropper3" },
		Button = Vector3.new(6, 0, ROW_PRODUCTION),
		Label = true,
		Machine = { Accepts = { "Metal" }, Output = "RobotPart", Multiplier = 2.5 },
		Parts = machine(6, Color3.fromRGB(0, 170, 255)),
	},
	{
		Id = "SideWalls",
		DisplayName = "Side Walls",
		Category = "Wall",
		Price = 1500,
		Requires = { "Assembler" },
		Button = Vector3.new(-20, 0, ROW_BUILDING),
		Parts = {
			{ Name = "Wall", Size = Vector3.new(1, 14, 70), CFrame = at(-49.5, 7, -15), Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.Concrete },
			{ Name = "Wall", Size = Vector3.new(1, 14, 70), CFrame = at(49.5, 7, -15), Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.Concrete },
			{ Name = "Stripe", Size = Vector3.new(1.2, 1, 70), CFrame = at(-49.5, 13, -15), Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Neon },
			{ Name = "Stripe", Size = Vector3.new(1.2, 1, 70), CFrame = at(49.5, 13, -15), Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Neon },
		},
	},
	{
		Id = "Painter",
		DisplayName = "Painter",
		Category = "Machine",
		Price = 3000,
		Requires = { "Assembler" },
		Button = Vector3.new(20, 0, ROW_PRODUCTION),
		Label = true,
		Machine = { Accepts = { "Scrap", "Metal", "RobotPart" }, Paint = true, Multiplier = 1.5 },
		Parts = machine(20, Color3.fromRGB(255, 80, 200)),
	},
	{
		Id = "Lamps",
		DisplayName = "Factory Lamps",
		Category = "Decoration",
		Price = 2000,
		Requires = { "Painter" },
		Button = Vector3.new(10, 0, ROW_BUILDING),
		Parts = concat(lampPost(-45, -45), lampPost(45, -45), lampPost(-45, 45), lampPost(45, 45)),
	},
	{
		Id = "Dropper4",
		DisplayName = "Industrial Dropper",
		Category = "Dropper",
		Price = 5000,
		Requires = { "Painter" },
		Button = Vector3.new(-18, 0, ROW_PRODUCTION),
		Dropper = { Interval = 1.5, Value = 18 },
		Parts = dropper(-18, Color3.fromRGB(70, 90, 160)),
	},

	-- Late game ---------------------------------------------------------------
	{
		Id = "ConveyorMk3",
		DisplayName = "Belt Motor Mk3",
		Category = "Conveyor",
		Price = 8000,
		Requires = { "Dropper4", "ConveyorMk2" },
		Button = Vector3.new(-10, 0, ROW_CONVEYOR),
		Conveyor = { SpeedMultiplier = 2.25 },
		Parts = motor(-30, Vector3.new(6, 5, 5), Color3.fromRGB(255, 60, 60)),
	},
	{
		Id = "FinalAssembly",
		DisplayName = "Final Assembly",
		Category = "Machine",
		Price = 12000,
		Requires = { "Painter" },
		Button = Vector3.new(33, 0, ROW_PRODUCTION),
		Label = true,
		Machine = { Accepts = { "RobotPart" }, Output = "Robot", Multiplier = 2, PartsPerRobot = 3 },
		Parts = machine(33, Color3.fromRGB(255, 215, 0)),
	},
	{
		Id = "ShowroomFloor",
		DisplayName = "Showroom Floor",
		Category = "Floor",
		Price = 6000,
		Requires = { "FinalAssembly" },
		Button = Vector3.new(20, 0, ROW_BUILDING),
		Parts = {
			{ Name = "Floor", Size = Vector3.new(98, 0.1, 50), CFrame = at(0, 0.05, 24), Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Marble },
		},
	},
	{
		Id = "RobotStatue",
		DisplayName = "Robot Statue",
		Category = "Decoration",
		Price = 25000,
		Requires = { "FinalAssembly" },
		Button = Vector3.new(30, 0, ROW_BUILDING),
		Parts = {
			{ Name = "Pedestal", Size = Vector3.new(6, 2, 6), CFrame = at(36, 1, 34), Color = DARK_METAL, Material = Enum.Material.Marble },
			{ Name = "Legs", Size = Vector3.new(3, 4, 1.5), CFrame = at(36, 4, 34), Color = STEEL, Material = Enum.Material.Metal },
			{ Name = "Torso", Size = Vector3.new(4, 4, 2), CFrame = at(36, 8, 34), Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Metal },
			{ Name = "Head", Size = Vector3.new(2.5, 2.5, 2.5), CFrame = at(36, 11.25, 34), Color = STEEL, Material = Enum.Material.Metal },
			{ Name = "Eyes", Size = Vector3.new(1.8, 0.5, 0.2), CFrame = at(36, 11.5, 35.3), Color = Color3.fromRGB(0, 255, 255), Material = Enum.Material.Neon },
		},
	},

	-- Game pass items (no button; built automatically for pass owners) -----------
	{
		Id = "VIPFloor",
		DisplayName = "VIP Lounge",
		Category = "Floor",
		Price = 0,
		Requires = {},
		GamePass = "VIPFloor",
		-- A golden lounge plus a VIP dropper that drops ready-smelted metal
		Dropper = { Interval = 2, Value = 30, Stage = "Metal" },
		Parts = concat(dropper(-2, Color3.fromRGB(255, 200, 40)), {
			{ Name = "VIPPlatform", Size = Vector3.new(22, 0.4, 20), CFrame = at(-37, 0.2, 36), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil },
			{ Name = "VIPRim", Size = Vector3.new(22.6, 0.3, 20.6), CFrame = at(-37, 0.15, 36), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon },
			{ Name = "VIPThrone", Size = Vector3.new(4, 5, 1), CFrame = at(-37, 2.9, 44), Color = Color3.fromRGB(150, 0, 200), Material = Enum.Material.Fabric },
			{ Name = "VIPSeat", Size = Vector3.new(4, 1, 3), CFrame = at(-37, 0.9, 42.5), Color = Color3.fromRGB(150, 0, 200), Material = Enum.Material.Fabric },
		}),
	},
}

return {
	Items = Items,
	Layout = {
		BeltZ = BELT_Z,
		BeltTop = BELT_TOP,
		BeltStart = BELT_START,
		BeltEnd = BELT_END,
	},
}
