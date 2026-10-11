--[[
	ArenaService
	A shared PvP arena floating above the map.
	  * Step on the portal in the lobby to enter; everyone gets a Robo Sword.
	  * Damage only happens between two players who are both in the arena
	    (attribute InArena), and all of it is dealt by the server.
	  * Players who own a Prototype robot can Deploy it: it follows them and
	    zaps the nearest enemy. More Prototypes = stronger zaps.
	  * Getting the last hit on someone earns cash (x rebirth multiplier).
	  * Dying, the exit portal, or the Leave button sends you home.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(Shared.Config.ArenaConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlotService, PlayerService, Net

local ArenaService = {}

local spawnPoints = {}
local lastHit = {} -- [victim Player] = { Attacker = Player, Time = number }
local swordCooldowns = {} -- [Player] = os.clock()
local portalCooldowns = {} -- [Player] = os.clock()
local companions = {} -- [Player] = { Model, CFrame, LastAttack }

-- Building -------------------------------------------------------------------

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

local function addSign(parentPart, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, height or 6, 0)
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = billboard
	billboard.Parent = parentPart
end

local function buildArena()
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local center, size, wallHeight = ArenaConfig.Center, ArenaConfig.Size, ArenaConfig.WallHeight
	local floorColor = Color3.fromRGB(35, 38, 48)

	part({
		Name = "Floor",
		Size = size,
		CFrame = CFrame.new(center - Vector3.new(0, size.Y / 2, 0)),
		Color = floorColor,
		Material = Enum.Material.DiamondPlate,
	}, folder)

	-- Neon grid lines
	for offset = -size.X / 2 + 20, size.X / 2 - 20, 20 do
		part({ Size = Vector3.new(0.4, 0.05, size.Z), CFrame = CFrame.new(center + Vector3.new(offset, 0.03, 0)), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon, CanCollide = false }, folder)
		part({ Size = Vector3.new(size.X, 0.05, 0.4), CFrame = CFrame.new(center + Vector3.new(0, 0.03, offset)), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon, CanCollide = false }, folder)
	end

	-- Walls (tall glass so nobody falls out)
	local walls = {
		{ Vector3.new(0, 0, -size.Z / 2), Vector3.new(size.X, wallHeight, 1) },
		{ Vector3.new(0, 0, size.Z / 2), Vector3.new(size.X, wallHeight, 1) },
		{ Vector3.new(-size.X / 2, 0, 0), Vector3.new(1, wallHeight, size.Z) },
		{ Vector3.new(size.X / 2, 0, 0), Vector3.new(1, wallHeight, size.Z) },
	}
	for _, wall in ipairs(walls) do
		local position = center + wall[1] + Vector3.new(0, wallHeight / 2, 0)
		part({ Name = "Wall", Size = wall[2], CFrame = CFrame.new(position), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Glass, Transparency = 0.6 }, folder)
		part({ Name = "WallTop", Size = wall[2] * Vector3.new(1, 0, 1) + Vector3.new(0, 0.6, 0), CFrame = CFrame.new(position + Vector3.new(0, wallHeight / 2, 0)), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon }, folder)
	end
	-- Invisible lid so jumps can't clear the walls
	part({ Name = "Ceiling", Size = Vector3.new(size.X, 1, size.Z), CFrame = CFrame.new(center + Vector3.new(0, wallHeight * 3, 0)), Transparency = 1 }, folder)

	-- Cover pillars
	for _, offset in ipairs({ Vector3.new(25, 0, 25), Vector3.new(-25, 0, 25), Vector3.new(25, 0, -25), Vector3.new(-25, 0, -25) }) do
		part({ Name = "Cover", Size = Vector3.new(8, 10, 8), CFrame = CFrame.new(center + offset + Vector3.new(0, 5, 0)), Color = Color3.fromRGB(60, 64, 78), Material = Enum.Material.Metal }, folder)
	end
	part({ Name = "CenterPlatform", Size = Vector3.new(18, 2, 18), CFrame = CFrame.new(center + Vector3.new(0, 1, 0)), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon, Transparency = 0.3 }, folder)

	-- Spawn ring
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * 50, 4, math.sin(angle) * 50)
		table.insert(spawnPoints, CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)))
	end

	-- Exit portal (inside the arena)
	local exitPad = part({
		Name = "ExitPortal",
		Size = Vector3.new(8, 0.6, 8),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, size.Z / 2 - 8)),
		Color = Color3.fromRGB(0, 170, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, folder)
	addSign(exitPad, "🏠 Back to your factory", Color3.fromRGB(120, 210, 255), 4)

	-- Entry portal (in the lobby aisle)
	local lobby = ArenaConfig.LobbyPortal
	local entryPad = part({
		Name = "ArenaPortal",
		Size = Vector3.new(10, 0.6, 10),
		CFrame = CFrame.new(lobby + Vector3.new(0, 0.3, 0)),
		Color = Color3.fromRGB(150, 60, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, folder)
	-- Arch opens toward the walkway (+Z / -Z)
	for _, x in ipairs({ -5.5, 5.5 }) do
		part({ Size = Vector3.new(1.5, 12, 1.5), CFrame = CFrame.new(lobby + Vector3.new(x, 6, 0)), Color = Color3.fromRGB(45, 47, 52), Material = Enum.Material.Metal }, folder)
	end
	part({ Size = Vector3.new(12.5, 1.5, 1.5), CFrame = CFrame.new(lobby + Vector3.new(0, 12.5, 0)), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon }, folder)
	addSign(entryPad, "⚔️ PvP ARENA ⚔️", Color3.fromRGB(220, 160, 255), 15)

	return entryPad, exitPad
end

-- Combat ---------------------------------------------------------------------

local function isFighter(player)
	if not player or not player:GetAttribute("InArena") then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function damage(attacker, victim, amount)
	if attacker == victim or not (isFighter(attacker) and isFighter(victim)) then
		return
	end
	local humanoid = victim.Character:FindFirstChildOfClass("Humanoid")
	lastHit[victim] = { Attacker = attacker, Time = os.clock() }
	humanoid:TakeDamage(amount) -- does nothing while the victim has a ForceField
end

local function onDied(victim)
	local hit = lastHit[victim]
	lastHit[victim] = nil
	if not hit or os.clock() - hit.Time > ArenaConfig.KillCreditTime then
		return
	end

	local killer = hit.Attacker
	local data = killer.Parent and DataService:GetData(killer)
	if data then
		local reward = ArenaConfig.KillReward * RebirthConfig.GetMultiplier(data.Rebirths)
		EconomyService:AddCash(killer, reward)
		Net:Notify(killer, ("You beat %s! +%s"):format(victim.DisplayName, Format.cash(reward)), "success")
		Net:Fire(killer, "CashPopup", math.floor(reward))
	end
	Net:Notify(victim, ("%s got you! Back to your factory."):format(killer.DisplayName), "error")
end

local function makeSword()
	local tool = Instance.new("Tool")
	tool.Name = "Robo Sword"
	tool.ToolTip = "Click to swing"
	tool.CanBeDropped = false
	-- Same grip as the classic Roblox sword
	tool.GripPos = Vector3.new(0, 0, -1.5)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 0.8, 4)
	handle.Color = Color3.fromRGB(0, 220, 255)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Activated:Connect(function()
		local character = tool.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not isFighter(player) then
			return
		end

		local now = os.clock()
		if now - (swordCooldowns[player] or 0) < ArenaConfig.Sword.Cooldown then
			return
		end
		swordCooldowns[player] = now

		-- Plays the default slash animation
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 1)

		local root = character.HumanoidRootPart
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and isFighter(other) then
				local offset = other.Character.HumanoidRootPart.Position - root.Position
				if offset.Magnitude <= ArenaConfig.Sword.Range and offset.Magnitude > 0 and root.CFrame.LookVector:Dot(offset.Unit) > 0.2 then
					damage(player, other, ArenaConfig.Sword.Damage)
				end
			end
		end
	end)

	return tool
end

-- Prototype companions -------------------------------------------------------

local function removeCompanion(player)
	local companion = companions[player]
	if companion then
		companion.Model:Destroy()
		companions[player] = nil
	end
	player:SetAttribute("PrototypeDeployed", false)
end

local function buildCompanion(player, startCFrame)
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Prototype"

	local function piece(name, size, offset, color)
		return part({
			Name = name,
			Size = size,
			CFrame = startCFrame * offset,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, model)
	end

	local body = piece("Body", Vector3.new(2, 2.2, 1.6), CFrame.new(), Color3.fromRGB(150, 60, 255))
	piece("Head", Vector3.new(1.5, 1.1, 1.2), CFrame.new(0, 1.7, 0), Color3.fromRGB(80, 220, 255))
	piece("Eyes", Vector3.new(1.1, 0.3, 0.1), CFrame.new(0, 1.8, -0.62), Color3.fromRGB(255, 60, 255))
	piece("Thruster", Vector3.new(1, 0.6, 1), CFrame.new(0, -1.4, 0), Color3.fromRGB(255, 170, 0))
	model.PrimaryPart = body

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 120, 255)
	sparkles.Parent = body
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 120, 255)
	light.Range = 14
	light.Brightness = 3
	light.Parent = body
	addSign(body, "★ " .. player.DisplayName .. "'s Prototype", Color3.fromRGB(255, 150, 255), 3)

	model.Parent = workspace:FindFirstChild("Arena") or workspace
	return model
end

local function laser(from, to)
	local distance = (to - from).Magnitude
	local beam = part({
		Name = "Zap",
		Size = Vector3.new(0.3, 0.3, distance),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2),
		Color = Color3.fromRGB(255, 80, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, workspace)
	Debris:AddItem(beam, 0.15)
end

local function updateCompanions()
	local now = os.clock()
	local config = ArenaConfig.Prototype

	for owner, companion in pairs(companions) do
		if not isFighter(owner) then
			removeCompanion(owner)
		else
			local root = owner.Character.HumanoidRootPart
			local bob = math.sin(now * 3) * 0.4
			local target = root.CFrame * CFrame.new(config.FollowOffset + Vector3.new(0, bob, 0))
			companion.CFrame = companion.CFrame:Lerp(target, 0.35)
			companion.Model:PivotTo(companion.CFrame)

			if now - companion.LastAttack >= config.Cooldown then
				local origin = companion.CFrame.Position
				local nearest, nearestDistance = nil, config.Range
				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= owner and isFighter(other) then
						local distance = (other.Character.HumanoidRootPart.Position - origin).Magnitude
						if distance < nearestDistance then
							nearest, nearestDistance = other, distance
						end
					end
				end

				if nearest then
					companion.LastAttack = now
					local data = DataService:GetData(owner)
					local extra = math.max(0, ((data and data.Prototypes) or 1) - 1)
					local bonus = math.min(config.MaxBonus, extra * config.ExtraPrototypeBonus)
					laser(origin, nearest.Character.HumanoidRootPart.Position)
					damage(owner, nearest, config.Damage * (1 + bonus))
				end
			end
		end
	end
end

-- Entering and leaving -------------------------------------------------------

local function removeSwords(player)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == "Robo Sword" then
					child:Destroy()
				end
			end
		end
	end
end

function ArenaService:Enter(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player:GetAttribute("InArena") or not humanoid or humanoid.Health <= 0 then
		return
	end

	player:SetAttribute("InArena", true)
	local spawnCFrame = spawnPoints[math.random(#spawnPoints)]
	-- With streaming enabled, load the arena first so the player doesn't fall through
	pcall(player.RequestStreamAroundAsync, player, spawnCFrame.Position, 5)
	if not character.Parent or humanoid.Health <= 0 then
		player:SetAttribute("InArena", false)
		return
	end
	character:PivotTo(spawnCFrame)

	local forceField = Instance.new("ForceField")
	forceField.Parent = character
	Debris:AddItem(forceField, ArenaConfig.SpawnProtection)

	removeSwords(player)
	makeSword().Parent = player:FindFirstChildOfClass("Backpack")

	humanoid.Died:Once(function()
		if player:GetAttribute("InArena") then
			onDied(player)
		end
	end)

	local data = DataService:GetData(player)
	if data and data.Prototypes > 0 then
		Net:Notify(player, "Welcome to the arena! Deploy your Prototype from the bottom of the screen.", "special")
	else
		Net:Notify(player, "Welcome to the arena! Click to swing your Robo Sword.", "info")
	end
end

function ArenaService:Leave(player: Player)
	if not player:GetAttribute("InArena") then
		return
	end
	player:SetAttribute("InArena", false)
	removeCompanion(player)
	removeSwords(player)
	lastHit[player] = nil
	task.spawn(PlotService.TeleportToPlot, PlotService, player)
end

local function deploy(player)
	local data = DataService:GetData(player)
	if not isFighter(player) or companions[player] then
		return
	end
	if not data or data.Prototypes <= 0 then
		Net:Notify(player, "You need a Prototype robot. Build one in your factory or get one in the shop!", "error")
		return
	end

	local root = player.Character.HumanoidRootPart
	local startCFrame = root.CFrame * CFrame.new(ArenaConfig.Prototype.FollowOffset)
	companions[player] = { Model = buildCompanion(player, startCFrame), CFrame = startCFrame, LastAttack = 0 }
	player:SetAttribute("PrototypeDeployed", true)
	Net:NotifyAll(player.DisplayName .. " deployed a ★ PROTOTYPE ★ in the arena!", "special")
end

local function onArenaAction(player, action)
	if action == "Leave" then
		ArenaService:Leave(player)
	elseif action == "Deploy" then
		deploy(player)
	elseif action == "Recall" then
		removeCompanion(player)
	end
end

local function hookPortal(pad, onTouch)
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("DataLoaded") ~= true then
			return
		end
		local now = os.clock()
		if now - (portalCooldowns[player] or 0) < 2 then
			return
		end
		portalCooldowns[player] = now
		onTouch(player)
	end)
end

function ArenaService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	Net = services.Net
end

function ArenaService:Start()
	local entryPad, exitPad = buildArena()
	hookPortal(entryPad, function(player)
		self:Enter(player)
	end)
	hookPortal(exitPad, function(player)
		self:Leave(player)
	end)

	Net:On("ArenaAction", onArenaAction, 2, 3)

	PlayerService.PlayerReady:Connect(function(player)
		player:SetAttribute("InArena", false)
		player.CharacterAdded:Connect(function()
			-- Respawning always sends you home (PlayerService teleports you)
			player:SetAttribute("InArena", false)
			removeCompanion(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeCompanion(player)
		lastHit[player] = nil
		swordCooldowns[player] = nil
		portalCooldowns[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / 15 then
			elapsed = 0
			updateCompanions()
		end
	end)
end

return ArenaService
