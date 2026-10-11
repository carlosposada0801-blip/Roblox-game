--[[
	DefenseService
	Rogue drones (DefenseConfig) raid factories that have cash waiting on
	the pad. They hover over the pad and drain a little cash every second
	until destroyed. Click/tap them (or shoot them) to destroy them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefenseConfig = require(Shared.Config.DefenseConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)

local DataService, EconomyService, PlotService, PlayerService, CombatService, QuestService, Net

local DefenseService = {}

local drones = {} -- [Model] = { Owner, Pad, Health, Phase, Offset }

local function buildDrone(position)
	local model = Instance.new("Model")
	model.Name = "RogueDrone"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3, 3)
	body.Color = Color3.fromRGB(60, 20, 25)
	body.Material = Enum.Material.Metal
	body.CFrame = CFrame.new(position)
	body.Parent = model
	model.PrimaryPart = body
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Anchored = true
	eye.CanCollide = false
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.new(1.2, 1.2, 1.2)
	eye.Color = Color3.fromRGB(255, 30, 30)
	eye.Material = Enum.Material.Neon
	eye.CFrame = body.CFrame * CFrame.new(0, 0, -1.2)
	eye.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 30, 30)
	light.Range = 10
	light.Parent = eye
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 26)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.TextStrokeTransparency = 0
	label.Text = "⚠ CLICK TO DESTROY"
	label.Parent = tag
	tag.Parent = body
	model.Parent = workspace
	return model
end

local function destroyDrone(model, destroyer)
	local drone = drones[model]
	if not drone then
		return
	end
	drones[model] = nil
	local explosion = Instance.new("Explosion")
	explosion.Position = model:GetPivot().Position
	explosion.BlastRadius = 4
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	model:Destroy()

	local data = destroyer and destroyer.Parent and DataService:GetData(destroyer)
	if data then
		local reward = DefenseConfig.Reward * RebirthConfig.GetMultiplier(data.Rebirths)
		EconomyService:AddCash(destroyer, reward)
		data.DroneKills += 1
		QuestService:Track(destroyer, "DronesDestroyed", 1)
		Net:Fire(destroyer, "CashPopup", math.floor(reward))
		Net:Fire(destroyer, "Sfx", "Cash")
	end
end

local function spawnRaid(owner, plot)
	local collector = plot.Model.Items:FindFirstChild("Collector")
	local pad = collector and collector:FindFirstChild("CashPad", true)
	if not pad then
		return
	end
	local count = math.random(DefenseConfig.DronesPerRaid[1], DefenseConfig.DronesPerRaid[2])
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local model = buildDrone(pad.Position + Vector3.new(math.cos(angle) * 30, 40, math.sin(angle) * 30))
		drones[model] = { Owner = owner, Pad = pad, Health = DefenseConfig.DroneHealth, Phase = angle, Arrived = false }
		CombatService:RegisterTarget(model, function(player, amount)
			local drone = drones[model]
			if not drone then
				return
			end
			drone.Health -= amount
			Net:FireAll("Fx", "Coins", model:GetPivot().Position)
			if drone.Health <= 0 then
				destroyDrone(model, player)
			end
		end, DefenseConfig.ClickDamage, 3)
	end
	Net:Notify(owner, ("🚨 %d rogue drone%s are stealing from your cash pad! Click them to destroy them!"):format(count, count == 1 and "" or "s"), "error")
	Net:Fire(owner, "Sfx", "Denied")
end

local function update(dt)
	local now = os.clock()
	for model, drone in pairs(drones) do
		if not (model.Parent and drone.Pad.Parent and drone.Owner.Parent) then
			drones[model] = nil
			model:Destroy()
			continue
		end
		local target = drone.Pad.Position + Vector3.new(math.cos(now + drone.Phase) * 4, 6 + math.sin(now * 3 + drone.Phase), math.sin(now + drone.Phase) * 4)
		local current = model:GetPivot().Position
		local nextPosition = current:Lerp(target, math.min(1, dt * 1.5))
		model:PivotTo(CFrame.lookAt(nextPosition, drone.Pad.Position))
		drone.Arrived = (nextPosition - target).Magnitude < 6
	end
end

local function drain()
	for _, drone in pairs(drones) do
		if drone.Arrived then
			local stolen = EconomyService:TakePending(drone.Owner, DefenseConfig.StealPercentPerSecond)
			if stolen > 0 then
				Net:FireAll("Fx", "Coins", drone.Pad.Position + Vector3.new(0, 2, 0))
			end
		end
	end
end

local function scheduleRaids(player)
	task.spawn(function()
		while player.Parent do
			task.wait(math.random(DefenseConfig.MinDelay, DefenseConfig.MaxDelay))
			local plot = PlotService:GetPlot(player)
			local pending = player:GetAttribute("PendingCash") or 0
			local busy = false
			for _, drone in pairs(drones) do
				busy = busy or drone.Owner == player
			end
			if plot and not busy and pending >= DefenseConfig.MinPendingToRaid and not player:GetAttribute("Pass_AutoCollect") then
				spawnRaid(player, plot)
			end
		end
	end)
end

function DefenseService:SpawnRaid(player)
	local plot = PlotService:GetPlot(player)
	if plot then
		spawnRaid(player, plot)
	end
end

function DefenseService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	CombatService = services.CombatService
	QuestService = services.QuestService
	Net = services.Net
end

function DefenseService:Start()
	PlayerService.PlayerReady:Connect(scheduleRaids)
	RunService.Heartbeat:Connect(update)
	task.spawn(function()
		while true do
			task.wait(1)
			drain()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for model, drone in pairs(drones) do
			if drone.Owner == player then
				drones[model] = nil
				model:Destroy()
			end
		end
	end)
end

return DefenseService
