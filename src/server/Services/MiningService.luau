--[[
	MiningService
	A floating crystal mine (MiningConfig) reached by a portal in the lobby.
	Hold E on ore rocks to mine them; they respawn after a while.
	Ore can be sold, or crafted into Machine Cores (+value to every machine).
	Attributes: Ore_<id>, Cores
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MiningConfig = require(Shared.Config.MiningConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)
local Portal = require(script.Parent.Parent.Util.Portal)

local DataService, EconomyService, PlayerService, Net

local MiningService = {}

local oresById = {}
for _, ore in ipairs(MiningConfig.Ores) do
	oresById[ore.Id] = ore
end

local rng = Random.new(7)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for id in pairs(oresById) do
		player:SetAttribute("Ore_" .. id, data.Ores[id] or 0)
	end
	player:SetAttribute("Cores", data.Cores)
end

function MiningService:GetMachineMultiplier(player: Player): number
	local data = DataService:GetData(player)
	return 1 + (data and data.Cores or 0) * MiningConfig.CoreBonus
end

local function makeNode(parent, ore, position)
	local node = part({
		Name = ore.Id .. "Ore",
		Size = Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2.5, 4), rng:NextNumber(3, 5)),
		CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		Color = ore.Color,
		Material = Enum.Material.Neon,
	}, parent)
	-- Dark rock around the glowing ore
	part({ Name = "Rock", Size = node.Size * 1.15, CFrame = node.CFrame * CFrame.new(0, -0.6, 0), Color = Color3.fromRGB(60, 55, 65), Material = Enum.Material.Slate, CanCollide = false }, node)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine " .. ore.Name
	prompt.ObjectText = "⛏️ Ore"
	prompt.HoldDuration = ore.MineTime
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = node

	prompt.Triggered:Connect(function(player)
		local data = DataService:GetData(player)
		if not data or not prompt.Enabled then
			return
		end
		local amount = math.random(ore.Amount[1], ore.Amount[2])
		data.Ores[ore.Id] = (data.Ores[ore.Id] or 0) + amount
		sync(player)
		Net:Fire(player, "Sfx", "Cash")
		Net:Fire(player, "Fx", "Coins", node.Position)
		Net:Notify(player, ("+%d %s"):format(amount, ore.Name), "success")
		-- Hide until it grows back
		prompt.Enabled = false
		node.Transparency = 0.85
		task.delay(ore.Respawn, function()
			if node.Parent then
				prompt.Enabled = true
				node.Transparency = 0
			end
		end)
	end)
end

local function buildMine()
	local folder = Instance.new("Folder")
	folder.Name = "Mine"
	folder.Parent = workspace
	local center = MiningConfig.Center

	part({ Name = "Floor", Size = Vector3.new(120, 4, 120), CFrame = CFrame.new(center - Vector3.new(0, 2, 0)), Color = Color3.fromRGB(70, 60, 80), Material = Enum.Material.Slate }, folder)
	-- Crystal pillars and cave walls
	for i = 1, 18 do
		local angle = i / 18 * math.pi * 2
		local height = rng:NextNumber(12, 30)
		part({ Name = "CaveWall", Size = Vector3.new(14, height, 10), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 60, height / 2, math.sin(angle) * 60)) * CFrame.Angles(0, -angle, 0), Color = Color3.fromRGB(55, 48, 66), Material = Enum.Material.Slate }, folder)
	end
	for i = 1, 10 do
		local angle = rng:NextNumber(0, 6.28)
		local distance = rng:NextNumber(20, 50)
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(2, rng:NextNumber(6, 14), 2),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * distance, 4, math.sin(angle) * distance)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(160, 90, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CanCollide = false,
		}, folder)
		local light = Instance.new("PointLight")
		light.Color = crystal.Color
		light.Range = 16
		light.Parent = crystal
	end

	local nodes = Instance.new("Folder")
	nodes.Name = "OreNodes"
	nodes.Parent = folder
	for _, ore in ipairs(MiningConfig.Ores) do
		for _ = 1, ore.Count do
			local angle = rng:NextNumber(0, 6.28)
			local distance = rng:NextNumber(10, 48)
			makeNode(nodes, ore, center + Vector3.new(math.cos(angle) * distance, 1.5, math.sin(angle) * distance))
		end
	end

	Portal.create("MineExit", center + Vector3.new(0, 0, 40), Color3.fromRGB(0, 170, 255), "🏠 BACK TO LOBBY", folder, function(player)
		Portal.teleport(player, CFrame.new(MiningConfig.LobbyPortal + Vector3.new(0, 4, 8)))
	end, false)
	Portal.create("MinePortal", MiningConfig.LobbyPortal, Color3.fromRGB(160, 90, 255), "⛏️ CRYSTAL MINE", workspace:FindFirstChild("Scenery") or workspace, function(player)
		Portal.teleport(player, CFrame.new(center + Vector3.new(0, 4, 30)))
	end)
end

local function mineAction(player, action, oreId, amount)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if action == "Craft" then
		if data.Cores >= MiningConfig.MaxCores then
			Net:Notify(player, "You already have the maximum number of Machine Cores.", "info")
			return
		end
		for id, needed in pairs(MiningConfig.CoreRecipe) do
			if (data.Ores[id] or 0) < needed then
				Net:Notify(player, ("You need %d %s."):format(needed, id), "error")
				return
			end
		end
		for id, needed in pairs(MiningConfig.CoreRecipe) do
			data.Ores[id] -= needed
		end
		data.Cores += 1
		sync(player)
		Net:Notify(player, ("⚙️ Crafted a Machine Core! Machines now +%d%% value."):format(data.Cores * MiningConfig.CoreBonus * 100), "special")
		Net:Fire(player, "Sfx", "Rebirth")
		Net:Fire(player, "Fx", "Confetti")
	elseif action == "Sell" then
		local ore = type(oreId) == "string" and oresById[oreId]
		if not ore or type(amount) ~= "number" then
			return
		end
		amount = math.clamp(math.floor(amount), 0, data.Ores[ore.Id] or 0)
		if amount <= 0 then
			return
		end
		data.Ores[ore.Id] -= amount
		local cash = amount * MiningConfig.SellPrices[ore.Id] * RebirthConfig.GetMultiplier(data.Rebirths)
		EconomyService:AddCash(player, cash)
		sync(player)
		Net:Fire(player, "CashPopup", math.floor(cash))
		Net:Fire(player, "Sfx", "Cash")
		Net:Notify(player, ("Sold %d %s for %s"):format(amount, ore.Name, Format.cash(cash)), "success")
	end
end

function MiningService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function MiningService:Start()
	buildMine()
	PlayerService.PlayerReady:Connect(sync)
	Net:On("MineAction", mineAction, 2, 4)
end

return MiningService
