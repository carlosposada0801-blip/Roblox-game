--[[
	BossService
	Raid boss (BossConfig): every Interval seconds a giant evil robot lands
	in the lobby. While it's alive everyone has their weapons, and anyone
	can also click/tap it. It stomps a random nearby player (red warning
	circle first). Everyone who damaged it shares the reward when it falls.
	workspace attributes: BossActive, BossHealth, BossMaxHealth, BossEndsAt,
	BossIncomingAt (countdown before it lands), BossNextAt (next scheduled raid)
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared.Config.BossConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, CombatService, CosmeticService, Net

local BossService = {}

local boss -- { Model, Health, MaxHealth, Damage = { [Player] = number }, Root }

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

local function buildBoss(position)
	local model = Instance.new("Model")
	model.Name = "RaidBoss"
	local base = CFrame.new(position)
	local dark = Color3.fromRGB(35, 30, 40)
	local red = Color3.fromRGB(255, 30, 40)
	local function piece(name, size, offset, color, material)
		return part({ Name = name, Size = size, CFrame = base * offset, Color = color, Material = material or Enum.Material.Metal, CanCollide = false }, model)
	end
	local torso = piece("Torso", Vector3.new(16, 16, 10), CFrame.new(0, 26, 0), dark, Enum.Material.DiamondPlate)
	model.PrimaryPart = torso
	piece("Core", Vector3.new(5, 5, 1), CFrame.new(0, 27, -5.2), red, Enum.Material.Neon)
	piece("LegL", Vector3.new(5, 18, 5), CFrame.new(-4.5, 9, 0), dark)
	piece("LegR", Vector3.new(5, 18, 5), CFrame.new(4.5, 9, 0), dark)
	piece("ArmL", Vector3.new(4, 16, 4), CFrame.new(-10.5, 25, 0), Color3.fromRGB(70, 60, 75))
	piece("ArmR", Vector3.new(4, 16, 4), CFrame.new(10.5, 25, 0), Color3.fromRGB(70, 60, 75))
	piece("Head", Vector3.new(9, 7, 8), CFrame.new(0, 37.5, 0), dark)
	piece("Eyes", Vector3.new(7, 1.5, 0.4), CFrame.new(0, 38, -4.1), red, Enum.Material.Neon)
	for _, x in ipairs({ -3, 3 }) do
		piece("Horn", Vector3.new(1, 4, 1), CFrame.new(x, 42.5, 0), red, Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = red
	light.Range = 40
	light.Brightness = 3
	light.Parent = torso
	local fire = Instance.new("Fire")
	fire.Color = red
	fire.Size = 10
	fire.Parent = model.Head

	-- Health bar
	local bar = Instance.new("BillboardGui")
	bar.Name = "HealthBar"
	bar.Size = UDim2.fromOffset(320, 46)
	bar.StudsOffset = Vector3.new(0, 20, 0)
	bar.AlwaysOnTop = true
	bar.MaxDistance = 400
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Sarpanch
	title.TextScaled = true
	title.TextColor3 = red
	title.TextStrokeTransparency = 0
	title.Text = "☠️ OMEGA DESTROYER ☠️"
	title.Parent = bar
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 18)
	back.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = red
	fill.BorderSizePixel = 0
	fill.Parent = back
	bar.Parent = torso

	model.Parent = workspace
	return model, fill
end

local function updateBar()
	if boss then
		workspace:SetAttribute("BossHealth", math.max(0, math.floor(boss.Health)))
		boss.Fill.Size = UDim2.fromScale(math.max(0, boss.Health / boss.MaxHealth), 1)
	end
end

local function finish(defeated)
	if not boss then
		return
	end
	local current = boss
	boss = nil
	workspace:SetAttribute("BossActive", false)
	CombatService:RefreshAll()

	local explosion = Instance.new("Explosion")
	explosion.Position = current.Model:GetPivot().Position + Vector3.new(0, 20, 0)
	explosion.BlastRadius = 30
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	current.Model:Destroy()

	if not defeated then
		Net:NotifyAll("☠️ The Omega Destroyer flew away... Better luck next time!", "error")
		return
	end

	local total = 0
	for _, amount in pairs(current.Damage) do
		total += amount
	end
	Net:NotifyAll("🏆 The Omega Destroyer has been defeated! Rewards for everyone who helped!", "special")
	local top, topAmount = nil, 0
	for player, amount in pairs(current.Damage) do
		if amount > topAmount then
			top, topAmount = player, amount
		end
	end
	for player, amount in pairs(current.Damage) do
		local data = player.Parent and DataService:GetData(player)
		if data then
			local share = math.max(0.25, amount / math.max(total, 1))
			local cash = BossConfig.Reward.Cash * share * RebirthConfig.GetMultiplier(data.Rebirths)
			EconomyService:AddCash(player, cash)
			EconomyService:AddStat(player, "Robots", BossConfig.Reward.Robots)
			data.BossKills += 1
			local text = ("+%s, +%d 🤖"):format(Format.cash(cash), BossConfig.Reward.Robots)
			if math.random() < BossConfig.Reward.PrototypeChance then
				EconomyService:AddStat(player, "Prototypes", 1)
				text ..= ", +1 ⭐ PROTOTYPE!"
			end
			local skinChance = if player == top then BossConfig.Reward.TopDamageSkinChance else BossConfig.Reward.SkinChance
			if math.random() < skinChance and CosmeticService:GiveSkin(player, BossConfig.Reward.Skin) then
				text ..= ", and the ULTRA RARE Omega Destroyer robot skin!"
				Net:NotifyAll(("🎰 %s got the ultra rare Omega Destroyer skin!"):format(player.DisplayName), "special")
			end
			Net:Notify(player, "Boss loot: " .. text, "success")
			Net:Fire(player, "Fx", "Confetti")
			Net:Fire(player, "Sfx", "Rebirth")
		end
	end
end

local function damageBoss(player, amount)
	if not boss or amount <= 0 then
		return
	end
	boss.Health -= amount
	boss.Damage[player] = (boss.Damage[player] or 0) + amount
	updateBar()
	if boss.Health <= 0 then
		finish(true)
	end
end

local function stomp(current)
	-- Pick a random living player near the boss
	local origin = current.Model:GetPivot().Position
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (root.Position - origin).Magnitude < BossConfig.Attack.Range then
			table.insert(candidates, root.Position)
		end
	end
	if #candidates == 0 then
		return
	end
	local target = candidates[math.random(#candidates)]
	local attack = BossConfig.Attack
	local warning = part({
		Name = "StompWarning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, attack.Radius * 2, attack.Radius * 2),
		CFrame = CFrame.new(target.X, 0.3, target.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 30, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
	}, workspace)
	-- The boss turns toward the target
	current.Model:PivotTo(CFrame.lookAt(origin, Vector3.new(target.X, origin.Y, target.Z)))
	task.wait(attack.WarningTime)
	if boss ~= current then
		warning:Destroy()
		return
	end
	warning.Transparency = 0
	Debris:AddItem(warning, 0.3)
	Net:FireAll("Fx", "Coins", Vector3.new(target.X, 1, target.Z))
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			if flat.Magnitude <= attack.Radius and root.Position.Y < 30 then
				humanoid:TakeDamage(attack.Damage)
			end
		end
	end
end

function BossService:Spawn()
	if boss then
		return false
	end
	local players = #Players:GetPlayers()
	local maxHealth = math.max(BossConfig.MinHealth, players * BossConfig.HealthPerPlayer)
	local model, fill = buildBoss(BossConfig.Position)
	boss = { Model = model, Health = maxHealth, MaxHealth = maxHealth, Damage = {}, Fill = fill }
	CombatService:RegisterTarget(model, damageBoss, BossConfig.ClickDamage, 12)

	workspace:SetAttribute("BossMaxHealth", maxHealth)
	workspace:SetAttribute("BossEndsAt", workspace:GetServerTimeNow() + BossConfig.Duration)
	workspace:SetAttribute("BossActive", true)
	updateBar()
	CombatService:RefreshAll()
	Net:NotifyAll("☠️ BOSS RAID! The Omega Destroyer has landed in the lobby! Grab your weapons!", "error")
	Net:FireAll("Sfx", "Rebirth")

	-- Landing effect
	local root = model.PrimaryPart
	local landing = model:GetPivot()
	model:PivotTo(landing * CFrame.new(0, 60, 0))
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	TweenService:Create(value, TweenInfo.new(1.5, Enum.EasingStyle.Bounce), { Value = landing }):Play()
	Debris:AddItem(value, 2)

	local current = boss
	task.spawn(function()
		task.wait(2)
		local ends = os.clock() + BossConfig.Duration
		while boss == current and os.clock() < ends do
			stomp(current)
			task.wait(BossConfig.Attack.Every)
		end
		if boss == current then
			finish(false)
		end
	end)
	return root ~= nil
end

function BossService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	CombatService = services.CombatService
	CosmeticService = services.CosmeticService
	Net = services.Net
	workspace:SetAttribute("BossActive", false)
end

-- Announces the boss, counts down (BossIncomingAt), then spawns it.
function BossService:Countdown(seconds: number)
	if boss or (workspace:GetAttribute("BossIncomingAt") or 0) > workspace:GetServerTimeNow() then
		return false
	end
	workspace:SetAttribute("BossIncomingAt", workspace:GetServerTimeNow() + seconds)
	Net:NotifyAll(("☠️ WARNING: The Omega Destroyer lands in the lobby in %d seconds! Get ready!"):format(seconds), "error")
	Net:FireAll("Sfx", "Event")
	task.delay(seconds, function()
		workspace:SetAttribute("BossIncomingAt", 0)
		self:Spawn()
	end)
	return true
end

function BossService:Start()
	task.spawn(function()
		local nextAt = workspace:GetServerTimeNow() + BossConfig.FirstDelay
		while true do
			workspace:SetAttribute("BossNextAt", nextAt)
			task.wait(math.max(0, nextAt - workspace:GetServerTimeNow() - BossConfig.Warning))
			if #Players:GetPlayers() > 0 then
				self:Countdown(BossConfig.Warning)
			end
			nextAt += BossConfig.Interval
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if boss then
			boss.Damage[player] = nil
		end
	end)
end

return BossService
