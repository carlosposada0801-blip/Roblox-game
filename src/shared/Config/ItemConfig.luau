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
-- z and y let the same builders place things on the upper floor.

local HAZARD = Color3.fromRGB(255, 200, 40)

local function dropper(x, color, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "Body", Size = Vector3.new(5, 4, 10), CFrame = at(x, y + 11, z), Color = color, Material = Enum.Material.Metal },
		{ Name = "Hopper", Size = Vector3.new(4, 1.5, 4), CFrame = at(x, y + 13.75, z), Color = DARK_METAL, Material = Enum.Material.DiamondPlate },
		{ Name = "Stripe", Size = Vector3.new(5.1, 0.5, 10.1), CFrame = at(x, y + 9.5, z), Color = HAZARD, Material = Enum.Material.Neon },
		{ Name = "Fan", Size = Vector3.new(4.5, 0.25, 0.7), CFrame = at(x, y + 14.7, z), Color = STEEL, Material = Enum.Material.Metal, Spin = 6 },
		{ Name = "Beacon", Size = Vector3.new(0.8, 0.8, 0.8), Shape = Enum.PartType.Ball, CFrame = at(x + 2, y + 13.4, z + 4.4), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, Light = { Brightness = 1, Range = 6, Color = Color3.fromRGB(255, 60, 60) } },
		{ Name = "Spout", Size = Vector3.new(2.5, 1.5, 2.5), CFrame = at(x, y + 8.25, z), Color = HAZARD, Material = Enum.Material.Neon },
		{ Name = "Leg", Size = Vector3.new(1, 9, 1), CFrame = at(x, y + 4.5, z - 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Leg", Size = Vector3.new(1, 9, 1), CFrame = at(x, y + 4.5, z + 4.5), Color = DARK_METAL, Material = Enum.Material.Metal },
	}
end

-- effect: extra parts that make each machine look different (fire, sparks, paint...)
local function machine(x, color, effect, z, y)
	z, y = z or BELT_Z, y or 0
	local parts = {
		{ Name = "Roof", Size = Vector3.new(6, 2, 10.5), CFrame = at(x, y + 9, z), Color = color, Material = Enum.Material.Metal },
		{ Name = "Glow", Size = Vector3.new(6.2, 0.6, 10.7), CFrame = at(x, y + 8, z), Color = color, Material = Enum.Material.Neon },
		{ Name = "Pillar", Size = Vector3.new(6, 8, 1.5), CFrame = at(x, y + 4, z - 4.5), Color = DARK_METAL, Material = Enum.Material.DiamondPlate },
		{ Name = "Pillar", Size = Vector3.new(6, 8, 1.5), CFrame = at(x, y + 4, z + 4.5), Color = DARK_METAL, Material = Enum.Material.DiamondPlate },
		{ Name = "PillarTrim", Size = Vector3.new(6.2, 0.4, 1.7), CFrame = at(x, y + 1, z - 4.5), Color = HAZARD, Material = Enum.Material.Neon },
		{ Name = "PillarTrim", Size = Vector3.new(6.2, 0.4, 1.7), CFrame = at(x, y + 1, z + 4.5), Color = HAZARD, Material = Enum.Material.Neon },
		{ Name = "GearHub", Size = Vector3.new(1.2, 1.6, 1.6), Shape = Enum.PartType.Cylinder, CFrame = at(x, y + 10.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = Enum.Material.Metal },
		{ Name = "GearArm", Size = Vector3.new(5, 0.4, 0.8), CFrame = at(x, y + 10.4, z), Color = color, Material = Enum.Material.Metal, Spin = 2 },
		{ Name = "GearArm", Size = Vector3.new(0.8, 0.4, 5), CFrame = at(x, y + 10.4, z), Color = color, Material = Enum.Material.Metal, Spin = 2 },
		{ Name = "Zone", Size = Vector3.new(4, 4, 6), CFrame = at(x, y + BELT_TOP + 2, z), Transparency = 1, CanCollide = false, CanQuery = false },
	}
	for _, extra in ipairs(effect or {}) do
		table.insert(parts, extra)
	end
	return parts
end

-- Machine effects
local function furnace(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "Furnace", Size = Vector3.new(3, 1, 3), CFrame = at(x, y + 7.3, z), Color = Color3.fromRGB(255, 120, 20), Material = Enum.Material.Neon, CanCollide = false, Fire = { Size = 4, Heat = 6, Color = Color3.fromRGB(255, 120, 20), SecondaryColor = Color3.fromRGB(255, 220, 60) }, Light = { Brightness = 3, Range = 14, Color = Color3.fromRGB(255, 140, 40) } },
		{ Name = "Chimney", Size = Vector3.new(1.6, 4, 1.6), CFrame = at(x + 1.8, y + 12, z - 3), Color = DARK_METAL, Material = Enum.Material.Metal, Smoke = { Color = Color3.fromRGB(90, 90, 100), Opacity = 0.15, RiseVelocity = 4, Size = 2 } },
	}
end
local function welder(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "WelderArm", Size = Vector3.new(0.6, 3, 0.6), CFrame = at(x, y + 6, z - 1.5), Color = STEEL, Material = Enum.Material.Metal, CanCollide = false },
		{ Name = "WelderTip", Size = Vector3.new(0.7, 0.7, 0.7), Shape = Enum.PartType.Ball, CFrame = at(x, y + 4.4, z - 1.5), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Emitter = { Texture = "Sparks", Rate = 30, Lifetime = 0.35, Speed = 7, Size = 0.35, Colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 140, 20) } }, Light = { Brightness = 2, Range = 10, Color = Color3.fromRGB(120, 220, 255) } },
	}
end
local function paintSpray(x, z, y)
	z, y = z or BELT_Z, y or 0
	local rainbow = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 220, 100), Color3.fromRGB(0, 170, 255), Color3.fromRGB(200, 90, 255) }
	return {
		{ Name = "Nozzle", Size = Vector3.new(1, 1, 1), CFrame = at(x, y + 7.3, z), Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon, CanCollide = false, Emitter = { Texture = "Square", Rate = 25, Lifetime = 0.7, Speed = 3, Size = 0.45, Spread = 25, Acceleration = Vector3.new(0, -25, 0), Colors = rainbow, LightEmission = 0.4 } },
		{ Name = "PaintTank", Size = Vector3.new(1.6, 2.6, 1.6), Shape = Enum.PartType.Cylinder, CFrame = at(x - 2, y + 11.5, z + 3) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Glass, Transparency = 0.3 },
	}
end
local function assemblyRig(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "Core", Size = Vector3.new(1.4, 1.4, 1.4), Shape = Enum.PartType.Ball, CFrame = at(x, y + 7.2, z), Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Neon, CanCollide = false, Sparkles = Color3.fromRGB(255, 230, 120), Light = { Brightness = 3, Range = 14, Color = Color3.fromRGB(255, 215, 0) } },
		{ Name = "RobotArm", Size = Vector3.new(4, 0.5, 0.5), CFrame = at(x, y + 6.6, z), Color = STEEL, Material = Enum.Material.Metal, CanCollide = false, Spin = 3 },
	}
end
local function laser(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "LaserBeam", Size = Vector3.new(0.25, 5, 0.25), CFrame = at(x, y + 5.2, z), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Emitter = { Texture = "Sparks", Rate = 25, Lifetime = 0.3, Speed = 6, Size = 0.3, Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 80) } }, Light = { Brightness = 3, Range = 12, Color = Color3.fromRGB(255, 40, 60) } },
	}
end
local function aiCore(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "Brain", Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Ball, CFrame = at(x, y + 12.2, z), Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon, CanCollide = false, Sparkles = Color3.fromRGB(120, 240, 255), Light = { Brightness = 4, Range = 18, Color = Color3.fromRGB(0, 230, 255) } },
		{ Name = "Ring", Size = Vector3.new(5, 0.3, 0.6), CFrame = at(x, y + 12.2, z), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, CanCollide = false, Spin = -4 },
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

-- Upper floor (second production line, unlocked after rebirths)
local UPPER_Y = 17 -- top of the upper floor
local UPPER_Z = -30 -- the upper belt runs along X at this depth
local UPPER_BELT_END = 38

local function upperFloor()
	local rampRise, rampRun = UPPER_Y, 38
	local rampLength = math.sqrt(rampRise ^ 2 + rampRun ^ 2)
	local rampAngle = math.atan2(rampRise, rampRun)
	local floorColor = Color3.fromRGB(50, 54, 64)
	local parts = {
		{ Name = "UpperFloor", Size = Vector3.new(100, 1, 42), CFrame = at(0, UPPER_Y - 0.5, -29), Color = floorColor, Material = Enum.Material.DiamondPlate },
		{ Name = "UpperEdge", Size = Vector3.new(92, 0.4, 0.6), CFrame = at(-4, UPPER_Y - 0.6, -8), Color = HAZARD, Material = Enum.Material.Neon },
		-- Ramp from the front-right of the plot up to the upper floor
		{ Name = "Ramp", Size = Vector3.new(6, 1, rampLength), CFrame = at(45, rampRise / 2 - 0.5, -8 + rampRun / 2) * CFrame.Angles(rampAngle, 0, 0), Color = floorColor, Material = Enum.Material.DiamondPlate },
		{ Name = "RampTrim", Size = Vector3.new(0.4, 1.4, rampLength), CFrame = at(41.8, rampRise / 2, -8 + rampRun / 2) * CFrame.Angles(rampAngle, 0, 0), Color = HAZARD, Material = Enum.Material.Neon },
		-- Upper conveyor
		{ Name = "Frame", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1.5, 7), CFrame = at((BELT_START + UPPER_BELT_END) / 2, UPPER_Y + 0.75, UPPER_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Belt", Size = Vector3.new(UPPER_BELT_END - BELT_START, 0.2, 6), CFrame = at((BELT_START + UPPER_BELT_END) / 2, UPPER_Y + BELT_TOP - 0.1, UPPER_Z), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Fabric },
		{ Name = "Rail", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + UPPER_BELT_END) / 2, UPPER_Y + BELT_TOP + 0.5, UPPER_Z - 3.25), Color = HAZARD, Material = Enum.Material.Metal },
		{ Name = "Rail", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + UPPER_BELT_END) / 2, UPPER_Y + BELT_TOP + 0.5, UPPER_Z + 3.25), Color = HAZARD, Material = Enum.Material.Metal },
		-- Upper collector bin (sells into the same cash pad downstairs)
		{ Name = "Base", Size = Vector3.new(7, 1, 9), CFrame = at(42.5, UPPER_Y + 0.5, UPPER_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Wall", Size = Vector3.new(1, 4, 9), CFrame = at(45.5, UPPER_Y + 3, UPPER_Z), Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Metal },
		{ Name = "Intake", Size = Vector3.new(6, 3, 7), CFrame = at(42, UPPER_Y + 2.5, UPPER_Z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Sparkles = Color3.fromRGB(120, 255, 150) },
	}
	-- Ceiling lights for the ground floor underneath
	for _, x in ipairs({ -30, 0, 30 }) do
		table.insert(parts, { Name = "CeilingLight", Size = Vector3.new(8, 0.3, 1), CFrame = at(x, UPPER_Y - 1.15, -22), Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Neon, Light = { Brightness = 2, Range = 22, Color = Color3.fromRGB(220, 240, 255) } })
	end
	-- Railings along the front edge
	for x = -46, 36, 8 do
		table.insert(parts, { Name = "Railing", Size = Vector3.new(0.4, 3, 0.4), CFrame = at(x, UPPER_Y + 1.5, -8.6), Color = STEEL, Material = Enum.Material.Metal })
	end
	table.insert(parts, { Name = "RailingTop", Size = Vector3.new(84, 0.4, 0.4), CFrame = at(-5, UPPER_Y + 3, -8.6), Color = HAZARD, Material = Enum.Material.Neon })
	return parts
end

-- Third floor (unlocked after more rebirths)
local THIRD_Y = 34
local LIFT_X, LIFT_Z = 32, -13

local function reactor(x, z, y)
	z, y = z or BELT_Z, y or 0
	return {
		{ Name = "ReactorCore", Size = Vector3.new(2.2, 2.2, 2.2), Shape = Enum.PartType.Ball, CFrame = at(x, y + 12.3, z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, CanCollide = false, Sparkles = Color3.fromRGB(150, 255, 180), Light = { Brightness = 4, Range = 18, Color = Color3.fromRGB(60, 255, 120) } },
		{ Name = "ReactorRing", Size = Vector3.new(5.5, 0.3, 0.5), CFrame = at(x, y + 12.3, z), Color = Color3.fromRGB(200, 255, 220), Material = Enum.Material.Neon, CanCollide = false, Spin = 5 },
		{ Name = "Plasma", Size = Vector3.new(1, 1, 1), CFrame = at(x, y + 7.3, z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, CanCollide = false, Emitter = { Texture = "Sparkle", Rate = 20, Lifetime = 0.6, Speed = 4, Size = 0.5, Colors = { Color3.fromRGB(60, 255, 120), Color3.fromRGB(0, 200, 255) } } },
	}
end

local function liftPad(name, y, destinationY, label)
	return {
		Name = name,
		Size = Vector3.new(5, 0.5, 5),
		CFrame = at(LIFT_X, y + 0.25, LIFT_Z),
		Color = Color3.fromRGB(60, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Sparkles = Color3.fromRGB(150, 255, 180),
		-- Land a few studs away from the other floor's pad
		Teleport = Vector3.new(LIFT_X, destinationY + 3, LIFT_Z - 7),
		Sign = label,
	}
end

local function thirdFloor()
	local floorColor = Color3.fromRGB(44, 40, 60)
	local accent = Color3.fromRGB(60, 255, 120)
	local parts = {
		{ Name = "ThirdFloor", Size = Vector3.new(100, 1, 42), CFrame = at(0, THIRD_Y - 0.5, -29), Color = floorColor, Material = Enum.Material.DiamondPlate },
		{ Name = "ThirdEdge", Size = Vector3.new(100, 0.4, 0.6), CFrame = at(0, THIRD_Y - 0.6, -8), Color = accent, Material = Enum.Material.Neon },
		-- Lifts between floor 2 and floor 3
		liftPad("LiftUp", UPPER_Y, THIRD_Y, "⬆ 3RD FLOOR"),
		liftPad("LiftDown", THIRD_Y, UPPER_Y, "⬇ 2ND FLOOR"),
		{ Name = "LiftShaft", Size = Vector3.new(0.6, THIRD_Y - UPPER_Y, 0.6), CFrame = at(LIFT_X - 2.8, (UPPER_Y + THIRD_Y) / 2, LIFT_Z - 2.8), Color = accent, Material = Enum.Material.Neon, CanCollide = false },
		{ Name = "LiftShaft", Size = Vector3.new(0.6, THIRD_Y - UPPER_Y, 0.6), CFrame = at(LIFT_X + 2.8, (UPPER_Y + THIRD_Y) / 2, LIFT_Z - 2.8), Color = accent, Material = Enum.Material.Neon, CanCollide = false },
		-- Third-floor conveyor
		{ Name = "Frame", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1.5, 7), CFrame = at((BELT_START + UPPER_BELT_END) / 2, THIRD_Y + 0.75, UPPER_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Belt", Size = Vector3.new(UPPER_BELT_END - BELT_START, 0.2, 6), CFrame = at((BELT_START + UPPER_BELT_END) / 2, THIRD_Y + BELT_TOP - 0.1, UPPER_Z), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Fabric },
		{ Name = "Rail", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + UPPER_BELT_END) / 2, THIRD_Y + BELT_TOP + 0.5, UPPER_Z - 3.25), Color = accent, Material = Enum.Material.Metal },
		{ Name = "Rail", Size = Vector3.new(UPPER_BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + UPPER_BELT_END) / 2, THIRD_Y + BELT_TOP + 0.5, UPPER_Z + 3.25), Color = accent, Material = Enum.Material.Metal },
		-- Third-floor collector
		{ Name = "Base", Size = Vector3.new(7, 1, 9), CFrame = at(42.5, THIRD_Y + 0.5, UPPER_Z), Color = DARK_METAL, Material = Enum.Material.Metal },
		{ Name = "Wall", Size = Vector3.new(1, 4, 9), CFrame = at(45.5, THIRD_Y + 3, UPPER_Z), Color = accent, Material = Enum.Material.Metal },
		{ Name = "Intake", Size = Vector3.new(6, 3, 7), CFrame = at(42, THIRD_Y + 2.5, UPPER_Z), Color = accent, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Sparkles = Color3.fromRGB(150, 255, 180) },
		{ Name = "RailingTop", Size = Vector3.new(100, 0.4, 0.4), CFrame = at(0, THIRD_Y + 3, -8.6), Color = accent, Material = Enum.Material.Neon },
	}
	-- Ceiling lights for the second floor underneath
	for _, x in ipairs({ -30, 0, 30 }) do
		table.insert(parts, { Name = "CeilingLight", Size = Vector3.new(8, 0.3, 1), CFrame = at(x, THIRD_Y - 1.15, -22), Color = Color3.fromRGB(220, 255, 230), Material = Enum.Material.Neon, Light = { Brightness = 2, Range = 22, Color = Color3.fromRGB(220, 255, 230) } })
	end
	for x = -46, 46, 8 do
		table.insert(parts, { Name = "Railing", Size = Vector3.new(0.4, 3, 0.4), CFrame = at(x, THIRD_Y + 1.5, -8.6), Color = STEEL, Material = Enum.Material.Metal })
	end
	return parts
end

-- Button rows (plot-local Z)
local ROW_PRODUCTION = -8 -- buttons sit right in front of the item they build
local ROW_CONVEYOR = 4
local ROW_BUILDING = 16
local ROW_EXPANSION = 26 -- second floor (needs rebirths)
local ROW_THIRD = 36 -- third floor (needs more rebirths)

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
			{ Name = "Rail", Size = Vector3.new(BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + BELT_END) / 2, BELT_TOP + 0.5, BELT_Z - 3.25), Color = HAZARD, Material = Enum.Material.Metal },
			{ Name = "Rail", Size = Vector3.new(BELT_END - BELT_START, 1, 0.5), CFrame = at((BELT_START + BELT_END) / 2, BELT_TOP + 0.5, BELT_Z + 3.25), Color = HAZARD, Material = Enum.Material.Metal },
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
			{ Name = "Intake", Size = Vector3.new(6, 3, 7), CFrame = at(44, 2.5, BELT_Z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Sparkles = Color3.fromRGB(120, 255, 150) },
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
		Parts = machine(-10, Color3.fromRGB(255, 100, 30), furnace(-10)),
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
		Parts = machine(6, Color3.fromRGB(0, 170, 255), welder(6)),
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
		Parts = machine(20, Color3.fromRGB(255, 80, 200), paintSpray(20)),
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
		Parts = machine(33, Color3.fromRGB(255, 215, 0), assemblyRig(33)),
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

	-- Second floor (needs 2 rebirths) --------------------------------------------
	{
		Id = "UpperFloor",
		DisplayName = "2nd Floor + Line",
		Category = "Floor",
		Price = 50000,
		MinRebirths = 2,
		Requires = { "FinalAssembly" },
		Button = Vector3.new(-18, 0, ROW_EXPANSION),
		Label = true,
		Conveyor = { SpeedMultiplier = 1 },
		Collector = {},
		Parts = upperFloor(),
	},
	{
		Id = "QuantumDropper1",
		DisplayName = "Quantum Dropper",
		Category = "Dropper",
		Price = 60000,
		MinRebirths = 2,
		Requires = { "UpperFloor" },
		Button = Vector3.new(-10, 0, ROW_EXPANSION),
		Dropper = { Interval = 1.5, Value = 60, Stage = "Metal" },
		Parts = dropper(-42, Color3.fromRGB(120, 60, 220), UPPER_Z, UPPER_Y),
	},
	{
		Id = "LaserCutter",
		DisplayName = "Laser Cutter",
		Category = "Machine",
		Price = 120000,
		MinRebirths = 2,
		Requires = { "QuantumDropper1" },
		Button = Vector3.new(10, 0, ROW_EXPANSION),
		Label = true,
		Machine = { Accepts = { "Metal" }, Output = "RobotPart", Multiplier = 3 },
		Parts = machine(-12, Color3.fromRGB(255, 40, 60), laser(-12, UPPER_Z, UPPER_Y), UPPER_Z, UPPER_Y),
	},
	{
		Id = "AICore",
		DisplayName = "AI Core",
		Category = "Machine",
		Price = 250000,
		MinRebirths = 2,
		Requires = { "LaserCutter" },
		Button = Vector3.new(18, 0, ROW_EXPANSION),
		Label = true,
		Machine = { Accepts = { "RobotPart" }, Output = "Robot", Multiplier = 3, PartsPerRobot = 2 },
		Parts = machine(20, Color3.fromRGB(0, 230, 255), aiCore(20, UPPER_Z, UPPER_Y), UPPER_Z, UPPER_Y),
	},
	{
		Id = "QuantumDropper2",
		DisplayName = "Quantum Dropper II",
		Category = "Dropper",
		Price = 400000,
		MinRebirths = 2,
		Requires = { "AICore" },
		Button = Vector3.new(26, 0, ROW_EXPANSION),
		Dropper = { Interval = 1.2, Value = 90, Stage = "Metal" },
		Parts = dropper(-32, Color3.fromRGB(120, 60, 220), UPPER_Z, UPPER_Y),
	},

	-- Third floor (needs 5 rebirths) ----------------------------------------------
	{
		Id = "ThirdFloor",
		DisplayName = "3rd Floor + Lift",
		Category = "Floor",
		Price = 600000,
		MinRebirths = 5,
		Requires = { "QuantumDropper2" },
		Button = Vector3.new(-18, 0, ROW_THIRD),
		Label = true,
		Conveyor = { SpeedMultiplier = 1 },
		Collector = {},
		Parts = thirdFloor(),
	},
	{
		Id = "PlasmaDropper1",
		DisplayName = "Plasma Dropper",
		Category = "Dropper",
		Price = 1000000,
		MinRebirths = 5,
		Requires = { "ThirdFloor" },
		Button = Vector3.new(-10, 0, ROW_THIRD),
		Dropper = { Interval = 1.5, Value = 400, Stage = "RobotPart" },
		Parts = dropper(-42, Color3.fromRGB(40, 200, 110), UPPER_Z, THIRD_Y),
	},
	{
		Id = "FusionReactor",
		DisplayName = "Fusion Reactor",
		Category = "Machine",
		Price = 2000000,
		MinRebirths = 5,
		Requires = { "PlasmaDropper1" },
		Button = Vector3.new(10, 0, ROW_THIRD),
		Label = true,
		Machine = { Accepts = { "RobotPart" }, Paint = true, Multiplier = 4 },
		Parts = machine(-12, Color3.fromRGB(60, 255, 120), reactor(-12, UPPER_Z, THIRD_Y), UPPER_Z, THIRD_Y),
	},
	{
		Id = "MegaAssembler",
		DisplayName = "Mega Assembler",
		Category = "Machine",
		Price = 4000000,
		MinRebirths = 5,
		Requires = { "FusionReactor" },
		Button = Vector3.new(18, 0, ROW_THIRD),
		Label = true,
		Machine = { Accepts = { "RobotPart" }, Output = "Robot", Multiplier = 4, PartsPerRobot = 2 },
		Parts = machine(20, Color3.fromRGB(255, 215, 0), assemblyRig(20, UPPER_Z, THIRD_Y), UPPER_Z, THIRD_Y),
	},
	{
		Id = "PlasmaDropper2",
		DisplayName = "Plasma Dropper II",
		Category = "Dropper",
		Price = 8000000,
		MinRebirths = 5,
		Requires = { "MegaAssembler" },
		Button = Vector3.new(26, 0, ROW_THIRD),
		Dropper = { Interval = 1.2, Value = 600, Stage = "RobotPart" },
		Parts = dropper(-32, Color3.fromRGB(40, 200, 110), UPPER_Z, THIRD_Y),
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
