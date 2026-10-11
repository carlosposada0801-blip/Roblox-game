--[[
	SceneryService
	Builds the world around the factory when the server starts:
	  * sky and lighting (Atmosphere, Sky, Clouds, Bloom, SunRays, ColorCorrection)
	  * terrain: grass ground, rolling hills, sandy lakes, a ring of snowy mountains
	  * trees, rocks, a paved plaza aisle with street lamps
	  * the speedy walkway: two lanes down the middle of the aisle moving in
	    opposite directions (anchored parts with velocity carry whoever stands
	    on them). The moving arrows are drawn by the client (WalkwayController).
	Everything is generated from SceneryConfig using a fixed seed, so the
	layout is the same on every server.

	Terrain and props are built in the background with frequent task.wait()s.
	Big terrain fills done in one go would hit Roblox's script timeout and
	stop the whole server script.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.SceneryConfig)

local World = SceneryConfig.World
local Terrain = workspace.Terrain

local SceneryService = {}

local rng = Random.new(SceneryConfig.Seed)

local function apply(instance, props)
	for key, value in pairs(props) do
		instance[key] = value
	end
	return instance
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, props)
	p.Parent = parent
	return p
end

-- Sky & lighting -------------------------------------------------------------

local function getOrCreate(parent, className)
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = parent
	return instance
end

local function setupLighting()
	apply(Lighting, SceneryConfig.Lighting)

	apply(getOrCreate(Lighting, "Atmosphere"), SceneryConfig.Atmosphere)

	local sky = getOrCreate(Lighting, "Sky")
	local skyConfig = SceneryConfig.Sky
	sky.StarCount = skyConfig.StarCount
	sky.SunAngularSize = skyConfig.SunAngularSize
	sky.MoonAngularSize = skyConfig.MoonAngularSize
	sky.CelestialBodiesShown = true
	if skyConfig.Skybox then
		for face, image in pairs(skyConfig.Skybox) do
			sky["Skybox" .. face] = image
		end
	end

	apply(getOrCreate(Lighting, "BloomEffect"), SceneryConfig.Bloom)
	apply(getOrCreate(Lighting, "SunRaysEffect"), SceneryConfig.SunRays)
	apply(getOrCreate(Lighting, "ColorCorrectionEffect"), SceneryConfig.ColorCorrection)

	apply(getOrCreate(Terrain, "Clouds"), SceneryConfig.Clouds)
end

-- Placement helpers ----------------------------------------------------------

local function inClearZone(x, z, margin)
	margin = margin or 0
	return math.abs(x) < World.ClearZone.X + margin and math.abs(z) < World.ClearZone.Y + margin
end

local function inLake(x, z, margin)
	margin = margin or 0
	for _, lake in ipairs(World.Lakes) do
		if
			math.abs(x - lake.Center.X) < lake.Size.X / 2 + margin
			and math.abs(z - lake.Center.Z) < lake.Size.Z / 2 + margin
		then
			return true
		end
	end
	return false
end

-- A random point in the square of half-size maxDistance, outside the clear zone and lakes
local function randomOpenPoint(maxDistance, margin)
	for _ = 1, 50 do
		local x = rng:NextNumber(-maxDistance, maxDistance)
		local z = rng:NextNumber(-maxDistance, maxDistance)
		if not inClearZone(x, z, margin) and not inLake(x, z, margin) then
			return x, z
		end
	end
	return nil
end

-- Terrain --------------------------------------------------------------------

-- Flat grass ground with its top at y = 0, filled in tiles so we can yield between them
local function buildGround()
	Terrain:Clear()

	local size = World.GroundSize
	local tile = 250
	for x = -size / 2, size / 2 - tile, tile do
		for z = -size / 2, size / 2 - tile, tile do
			Terrain:FillBlock(CFrame.new(x + tile / 2, -6, z + tile / 2), Vector3.new(tile, 12, tile), Enum.Material.Grass)
			task.wait()
		end
	end
end

local function buildTerrain()

	-- Lakes with a sandy shore
	for _, lake in ipairs(World.Lakes) do
		local depth = lake.Size.Y
		Terrain:FillBlock(
			CFrame.new(lake.Center + Vector3.new(0, -2, 0)),
			Vector3.new(lake.Size.X + 20, 4, lake.Size.Z + 20),
			Enum.Material.Sand
		)
		Terrain:FillBlock(
			CFrame.new(lake.Center + Vector3.new(0, -depth / 2, 0)),
			Vector3.new(lake.Size.X, depth, lake.Size.Z),
			Enum.Material.Water
		)
		task.wait()
	end
	Terrain.WaterColor = World.WaterColor
	Terrain.WaterTransparency = 0.4
	Terrain.WaterWaveSize = 0.12
	Terrain.WaterWaveSpeed = 8
	Terrain.WaterReflectance = 0.6

	-- Rolling hills just outside the play area
	local hills = World.Hills
	for _ = 1, hills.Count do
		local radius = rng:NextNumber(hills.MinRadius, hills.MaxRadius)
		local x, z = randomOpenPoint(hills.MaxDistance, radius)
		if x then
			Terrain:FillBall(Vector3.new(x, -radius * 0.55, z), radius, Enum.Material.Grass)
			task.wait()
		end
	end

	-- Ring of mountains with rocky sides and snowy peaks
	local mountains = World.Mountains
	for index = 1, mountains.Count do
		local angle = (index / mountains.Count) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local distance = rng:NextNumber(mountains.MinDistance, mountains.MaxDistance)
		local radius = rng:NextNumber(mountains.MinRadius, mountains.MaxRadius)
		local center = Vector3.new(math.cos(angle) * distance, -radius * 0.3, math.sin(angle) * distance)

		-- Later fills replace earlier ones: dirt skirt, then rock body, then snow cap
		Terrain:FillBall(center + Vector3.new(0, -radius * 0.5, 0), radius * 1.15, Enum.Material.Ground)
		task.wait()
		Terrain:FillBall(center, radius, Enum.Material.Rock)
		task.wait()
		Terrain:FillBall(center + Vector3.new(0, radius * 0.62, 0), radius * 0.38, Enum.Material.Snow)
		task.wait()
	end
end

-- Props ----------------------------------------------------------------------

local LEAF_COLORS = {
	Color3.fromRGB(70, 160, 70),
	Color3.fromRGB(90, 180, 80),
	Color3.fromRGB(55, 135, 75),
	Color3.fromRGB(255, 150, 190), -- a few cherry-blossom trees
	Color3.fromRGB(240, 170, 60), -- and autumn ones
}

local function buildTree(parent, x, z)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local scale = rng:NextNumber(0.8, 1.6)
	local trunkHeight = 10 * scale

	-- Cylinders stand along X, so rotate them upright
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(x, trunkHeight / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(105, 70, 45),
		Material = Enum.Material.Wood,
	}, model)

	local isPine = rng:NextNumber() < 0.35
	if isPine then
		for layer = 0, 2 do
			local width = (7 - layer * 2) * scale
			part({
				Name = "Leaves",
				Size = Vector3.new(width, 3 * scale, width),
				CFrame = CFrame.new(x, trunkHeight * 0.55 + layer * 3 * scale, z) * CFrame.Angles(0, math.rad(45 * layer), 0),
				Color = Color3.fromRGB(40, 110, 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
			}, model)
		end
	else
		local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
		for _ = 1, 3 do
			local size = rng:NextNumber(5, 8) * scale
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(
					x + rng:NextNumber(-2, 2) * scale,
					trunkHeight + rng:NextNumber(-1, 2) * scale,
					z + rng:NextNumber(-2, 2) * scale
				),
				Color = color,
				Material = Enum.Material.Grass,
				CanCollide = false,
			}, model)
		end
	end

	model.Parent = parent
end

local function buildProps(folder)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	for index = 1, World.Trees.Count do
		local x, z = randomOpenPoint(World.Trees.MaxDistance, 8)
		if x then
			buildTree(trees, x, z)
		end
		if index % 20 == 0 then
			task.wait()
		end
	end

	local rocks = Instance.new("Folder")
	rocks.Name = "Rocks"
	rocks.Parent = folder
	for _ = 1, World.Rocks.Count do
		local x, z = randomOpenPoint(World.Rocks.MaxDistance, 6)
		if x then
			local size = Vector3.new(rng:NextNumber(3, 9), rng:NextNumber(2, 6), rng:NextNumber(3, 9))
			part({
				Name = "Rock",
				Size = size,
				CFrame = CFrame.new(x, size.Y * 0.3, z)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
				Color = Color3.fromRGB(rng:NextInteger(110, 140), rng:NextInteger(110, 135), rng:NextInteger(115, 140)),
				Material = Enum.Material.Rock,
			}, rocks)
		end
	end
end

-- Plaza, lamps and walkway ---------------------------------------------------

local function buildPlaza(folder)
	local plaza = World.Plaza
	part({
		Name = "Plaza",
		Size = plaza.Size,
		CFrame = CFrame.new(0, plaza.Size.Y / 2, 0),
		Color = plaza.Color,
		Material = Enum.Material.Pavement,
	}, folder)

	-- Street lamps along both edges of the aisle
	local lamps = World.StreetLamps
	local halfLength = plaza.Size.X / 2 - 10
	-- Offset by half a gap so no lamp lands in the middle (leaderboard and portal)
	for x = -halfLength + lamps.Spacing / 2, halfLength, lamps.Spacing do
		for _, z in ipairs({ -lamps.Z, lamps.Z }) do
			part({ Name = "LampPole", Size = Vector3.new(0.8, 14, 0.8), CFrame = CFrame.new(x, 7, z), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal }, folder)
			local bulb = part({
				Name = "LampBulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = CFrame.new(x, 14.6, z),
				Color = Color3.fromRGB(255, 230, 180),
				Material = Enum.Material.Neon,
			}, folder)
			local light = Instance.new("PointLight")
			light.Brightness = 1.5
			light.Range = 26
			light.Color = Color3.fromRGB(255, 220, 170)
			light.Parent = bulb
		end
	end
end

local function buildWalkway(folder)
	local config = SceneryConfig.Walkway
	local walkway = Instance.new("Folder")
	walkway.Name = "Walkway"
	walkway.Parent = folder

	for index, lane in ipairs(config.Lanes) do
		local belt = part({
			Name = "Lane" .. index,
			Size = Vector3.new(config.Length, config.Height, config.LaneWidth),
			CFrame = CFrame.new(0, config.Height / 2 + 0.1, lane.Z),
			Color = Color3.fromRGB(35, 37, 45),
			Material = Enum.Material.Rubber,
		}, walkway)
		-- An anchored part with velocity carries characters standing on it
		belt.AssemblyLinearVelocity = Vector3.new(lane.Direction * config.Speed, 0, 0)
		belt:SetAttribute("Direction", lane.Direction)
		belt:SetAttribute("Speed", config.Speed)
		belt:SetAttribute("Color", lane.Color)

		-- Glowing side trim
		for _, side in ipairs({ -1, 1 }) do
			part({
				Name = "Trim",
				Size = Vector3.new(config.Length, config.Height + 0.1, 0.4),
				CFrame = CFrame.new(0, (config.Height + 0.1) / 2 + 0.1, lane.Z + side * (config.LaneWidth / 2 + 0.2)),
				Color = lane.Color,
				Material = Enum.Material.Neon,
			}, walkway)
		end

		-- End caps so riders notice the lane ending
		for _, endSide in ipairs({ -1, 1 }) do
			part({
				Name = "EndCap",
				Size = Vector3.new(1, config.Height + 0.1, config.LaneWidth),
				CFrame = CFrame.new(endSide * (config.Length / 2 + 0.5), (config.Height + 0.1) / 2 + 0.1, lane.Z),
				Color = Color3.fromRGB(255, 220, 60),
				Material = Enum.Material.Neon,
			}, walkway)
		end
	end
end

function SceneryService:Init()
	local existing = workspace:FindFirstChild("Scenery")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = workspace

	-- Quick parts first, so the lobby works right away
	setupLighting()
	buildPlaza(folder)
	buildWalkway(folder)

	-- Heavy terrain and props in the background
	task.spawn(function()
		local started = os.clock()
		buildGround()

		-- The Studio Baseplate template's plate would cover the terrain
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end

		buildTerrain()
		buildProps(folder)
		print(("[SceneryService] World built in %.1fs"):format(os.clock() - started))
	end)
end

return SceneryService
