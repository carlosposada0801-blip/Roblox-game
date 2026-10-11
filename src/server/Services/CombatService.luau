--[[
	CombatService
	Weapons, damage, the PvP switch and kill rewards.

	Who can hurt whom (IsHostile):
	  * two players both inside the arena, or
	  * two players both outside the arena who both have PvP switched on.
	Players are "armed" (weapons in their backpack) while in the arena or
	while PvP is on.

	All damage is dealt here, on the server:
	  * Melee: the server handles Tool.Activated and checks range and facing.
	  * Ranged: the client sends FireWeapon(id, target). The server checks the
	    weapon is owned and equipped, the cooldown, the range, then raycasts
	    from the player's head itself.
	  * Rocket: a server-simulated projectile that explodes on impact.
	Knockouts give cash (x rebirth multiplier); arena knockouts also score
	round points.

	Targets: other services register non-player targets (raid boss, rogue
	drones) with RegisterTarget. Weapons hit them, and players can also
	click/tap them. Everyone is armed while a boss raid is on.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local ArenaConfig = require(Shared.Config.ArenaConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlayerService, QuestService, ArenaService, Net

local CombatService = {}

local weaponsById = {}
for _, weapon in ipairs(WeaponConfig.Weapons) do
	weaponsById[weapon.Id] = weapon
end

local targets = {} -- [Model] = { OnDamage = fn(player, amount), Radius = number }
local lastHit = {} -- [victim] = { Attacker, Time }
local lastCombat = {} -- [player] = os.clock() of last hit given or taken
local cooldowns = {} -- [player] = { [weaponId] = os.clock() }

-- Rules ----------------------------------------------------------------------------

local function alive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

function CombatService:IsHostile(a: Player, b: Player): boolean
	if a == b or not (alive(a) and alive(b)) then
		return false
	end
	local aArena, bArena = a:GetAttribute("InArena") == true, b:GetAttribute("InArena") == true
	if aArena and bArena then
		return true
	end
	return not aArena and not bArena and a:GetAttribute("PvP") == true and b:GetAttribute("PvP") == true
end

local function isArmed(player)
	return player:GetAttribute("InArena") == true
		or player:GetAttribute("PvP") == true
		or workspace:GetAttribute("BossActive") == true
end

-- Non-player targets ----------------------------------------------------------------

function CombatService:RegisterTarget(model: Model, onDamage, clickDamage: number?, radius: number?)
	targets[model] = { OnDamage = onDamage, Radius = radius or 4 }
	local clickPart = model.PrimaryPart
	if clickPart and clickDamage then
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 120
		detector.Parent = clickPart
		local lastClick = {}
		detector.MouseClick:Connect(function(player)
			if os.clock() - (lastClick[player] or 0) < 0.25 or not alive(player) then
				return
			end
			lastClick[player] = os.clock()
			onDamage(player, clickDamage)
		end)
	end
	model.Destroying:Connect(function()
		targets[model] = nil
	end)
end

function CombatService:UnregisterTarget(model: Model)
	targets[model] = nil
end

local function targetFromPart(part)
	local current = part
	while current and current ~= workspace do
		if targets[current] then
			return current, targets[current]
		end
		current = current.Parent
	end
	return nil
end

local function hitTargetsInRadius(player, position, radius, amount, facing)
	for model, target in pairs(targets) do
		if model.Parent then
			local offset = model:GetPivot().Position - position
			local reach = radius + target.Radius
			if offset.Magnitude <= reach and (not facing or offset.Magnitude < 0.1 or facing:Dot(offset.Unit) > 0) then
				target.OnDamage(player, amount)
			end
		end
	end
end

function CombatService:Damage(attacker: Player, victim: Player, amount: number)
	if not self:IsHostile(attacker, victim) then
		return false
	end
	local character = victim.Character :: Model -- IsHostile checked the victim is alive
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	lastHit[victim] = { Attacker = attacker, Time = os.clock() }
	lastCombat[attacker] = os.clock()
	lastCombat[victim] = os.clock()
	humanoid:TakeDamage(amount) -- does nothing while the victim has a ForceField
	return true
end

local function onDied(victim, diedInArena)
	local hit = lastHit[victim]
	lastHit[victim] = nil
	if not hit or os.clock() - hit.Time > ArenaConfig.KillCreditTime then
		return
	end

	local killer = hit.Attacker
	local data = killer.Parent and DataService:GetData(killer)
	if data then
		data.Kills += 1
		if diedInArena then
			ArenaService:AddScore(killer, ArenaConfig.Rounds.KnockoutPoints)
			QuestService:Track(killer, "ArenaKnockouts", 1)
		end
		local reward = ArenaConfig.KillReward * RebirthConfig.GetMultiplier(data.Rebirths)
		EconomyService:AddCash(killer, reward)
		Net:Notify(killer, ("💥 You knocked out %s! +%s"):format(victim.DisplayName, Format.cash(reward)), "success")
		Net:Fire(killer, "CashPopup", math.floor(reward))
		Net:Fire(killer, "Sfx", "Cash")
	end
	Net:Notify(victim, ("%s knocked you out! Back to your factory."):format(killer.DisplayName), "error")
end

-- Weapon tools ----------------------------------------------------------------------

local function weld(handle, part)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = handle
	constraint.Part1 = part
	constraint.Parent = part
	part.CanCollide = false
	part.Massless = true
	part.Parent = handle.Parent
end

local function newPart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function onMelee(tool, weapon)
	local character = tool.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not (player and alive(player)) then
		return
	end
	local playerCooldowns = cooldowns[player] or {}
	cooldowns[player] = playerCooldowns
	local now = os.clock()
	if now - (playerCooldowns[weapon.Id] or 0) < weapon.Cooldown then
		return
	end
	playerCooldowns[weapon.Id] = now

	-- Plays the default slash animation
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)

	local root = character.HumanoidRootPart
	for _, other in ipairs(Players:GetPlayers()) do
		if CombatService:IsHostile(player, other) then
			local offset = other.Character.HumanoidRootPart.Position - root.Position
			if offset.Magnitude <= weapon.Range and offset.Magnitude > 0 and root.CFrame.LookVector:Dot(offset.Unit) > 0.2 then
				CombatService:Damage(player, other, weapon.Damage)
			end
		end
	end
	hitTargetsInRadius(player, root.Position, weapon.Range, weapon.Damage, root.CFrame.LookVector)
end

local function buildTool(weapon)
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.ToolTip = weapon.Description
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weapon.Id)
	tool:SetAttribute("WeaponType", weapon.Type)

	local handle
	if weapon.Type == "Melee" and weapon.Id == "PlasmaHammer" then
		handle = newPart("Handle", Vector3.new(0.5, 0.5, 4), Color3.fromRGB(60, 62, 70))
		handle.Parent = tool
		local head = newPart("Head", Vector3.new(2.4, 1.6, 1.6), weapon.Color, Enum.Material.Neon)
		head.CFrame = handle.CFrame * CFrame.new(0, 0, -2.2)
		weld(handle, head)
		tool.GripPos = Vector3.new(0, 0, 1.2)
	elseif weapon.Type == "Melee" then
		-- Same grip as the classic Roblox sword
		handle = newPart("Handle", Vector3.new(1, 0.8, 4), weapon.Color, Enum.Material.Neon)
		handle.Parent = tool
		tool.GripPos = Vector3.new(0, 0, -1.5)
		tool.GripForward = Vector3.new(-1, 0, 0)
		tool.GripRight = Vector3.new(0, 1, 0)
		tool.GripUp = Vector3.new(0, 0, 1)
	else
		handle = newPart("Handle", Vector3.new(0.6, 1, 1.4), Color3.fromRGB(40, 42, 50))
		handle.Parent = tool
		local length = if weapon.Type == "Rocket" then 3.4 else 2.4
		local body = newPart("Body", Vector3.new(0.8, 0.8, length), Color3.fromRGB(70, 74, 86))
		body.CFrame = handle.CFrame * CFrame.new(0, 0.6, -length / 2 + 0.4)
		weld(handle, body)
		local glow = newPart("Glow", Vector3.new(0.85, 0.3, length * 0.7), weapon.Color, Enum.Material.Neon)
		glow.CFrame = body.CFrame * CFrame.new(0, 0.3, 0)
		weld(handle, glow)
		local muzzle = newPart("Muzzle", Vector3.new(0.5, 0.5, 0.3), weapon.Color, Enum.Material.Neon)
		muzzle.CFrame = body.CFrame * CFrame.new(0, 0, -length / 2 - 0.15)
		weld(handle, muzzle)
		tool.GripPos = Vector3.new(0, -0.2, 0.2)
	end

	if weapon.Type == "Melee" then
		tool.Activated:Connect(function()
			onMelee(tool, weapon)
		end)
	end
	return tool
end

local function ownsWeapon(player, weapon)
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	if weapon.RequiresPrototype then
		return data.Prototypes > 0
	end
	return data.Weapons[weapon.Id] == true
end

local function removeWeapons(player)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") then
					child:Destroy()
				end
			end
		end
	end
end

local function hasTool(player, weaponId)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
					return true
				end
			end
		end
	end
	return false
end

-- Gives (or takes away) weapons to match whether the player can fight right now
function CombatService:RefreshWeapons(player: Player)
	if not isArmed(player) then
		removeWeapons(player)
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, weapon in ipairs(WeaponConfig.Weapons) do
		if ownsWeapon(player, weapon) and not hasTool(player, weapon.Id) then
			buildTool(weapon).Parent = backpack
		end
	end
end

-- PvP name tag so everyone can see who is fair game
local function updateTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("PvPTag")
	if player:GetAttribute("PvP") then
		if not tag then
			tag = Instance.new("BillboardGui")
			tag.Name = "PvPTag"
			tag.Size = UDim2.fromOffset(80, 24)
			tag.StudsOffset = Vector3.new(0, 2.6, 0)
			tag.MaxDistance = 120
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
			label.BackgroundTransparency = 0.2
			label.Font = Enum.Font.Sarpanch
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "⚔️ PVP"
			label.Parent = tag
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = label
			tag.Parent = head
		end
	elseif tag then
		tag:Destroy()
	end
end

-- Ranged and rockets ---------------------------------------------------------------------

local function equippedWeapon(player, weaponId)
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
			return child
		end
	end
	return nil
end

local function playerFromPart(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return player
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function explode(attacker, weapon, position)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = weapon.Radius
	explosion.BlastPressure = 0 -- visual only; damage is applied below
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	for _, other in ipairs(Players:GetPlayers()) do
		if CombatService:IsHostile(attacker, other) then
			local distance = (other.Character.HumanoidRootPart.Position - position).Magnitude
			if distance <= weapon.Radius then
				CombatService:Damage(attacker, other, weapon.Damage * (1 - 0.5 * distance / weapon.Radius))
			end
		end
	end
	hitTargetsInRadius(attacker, position, weapon.Radius, weapon.Damage)
end

local function launchRocket(attacker, weapon, origin, direction, ignore)
	local rocket = Instance.new("Part")
	rocket.Name = "Rocket"
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.Size = Vector3.new(0.6, 0.6, 2)
	rocket.Color = weapon.Color
	rocket.Material = Enum.Material.Neon
	rocket.CFrame = CFrame.lookAt(origin, origin + direction)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 0
	fire.Parent = rocket
	rocket.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore, rocket }

	local travelled = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local stepLength = weapon.Speed * dt
		local position = rocket.Position
		local result = workspace:Raycast(position, direction * stepLength, params)
		travelled += stepLength
		if result or travelled >= weapon.Range then
			connection:Disconnect()
			local hitPosition = if result then result.Position else position + direction * stepLength
			rocket:Destroy()
			explode(attacker, weapon, hitPosition)
			return
		end
		rocket.CFrame = CFrame.lookAt(position + direction * stepLength, position + direction * stepLength * 2)
	end)
end

local function fireWeapon(player, weaponId, target)
	local weapon = type(weaponId) == "string" and weaponsById[weaponId]
	if not weapon or weapon.Type == "Melee" or typeof(target) ~= "Vector3" or not alive(player) or not isArmed(player) then
		return
	end
	if not ownsWeapon(player, weapon) or not equippedWeapon(player, weaponId) then
		return
	end
	local playerCooldowns = cooldowns[player] or {}
	cooldowns[player] = playerCooldowns
	local now = os.clock()
	if now - (playerCooldowns[weapon.Id] or 0) < weapon.Cooldown * 0.9 then
		return
	end
	playerCooldowns[weapon.Id] = now

	local character = player.Character
	local head = character:FindFirstChild("Head") or character.HumanoidRootPart
	local origin = head.Position
	local offset = target - origin
	if offset.Magnitude < 0.1 then
		return
	end
	local direction = offset.Unit

	if weapon.Type == "Rocket" then
		launchRocket(player, weapon, origin + direction * 3, direction, character)
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction * weapon.Range, params)
	local hitPosition = if result then result.Position else origin + direction * weapon.Range
	local victim = result and playerFromPart(result.Instance)
	if victim then
		CombatService:Damage(player, victim, weapon.Damage)
	elseif result then
		local _, hitTarget = targetFromPart(result.Instance)
		if hitTarget then
			hitTarget.OnDamage(player, weapon.Damage)
		end
	end
	Net:FireAll("Fx", "Shot", origin + direction * 1.5, hitPosition, weapon.Color)
end

-- Armory and PvP switch -------------------------------------------------------------------

local function buyWeapon(player, weaponId)
	local weapon = type(weaponId) == "string" and weaponsById[weaponId]
	local data = DataService:GetData(player)
	if not (weapon and data) or weapon.RequiresPrototype or data.Weapons[weapon.Id] then
		return
	end
	if not EconomyService:TrySpend(player, weapon.Price) then
		Net:Notify(player, ("%s costs %s."):format(weapon.DisplayName, Format.cash(weapon.Price)), "error")
		Net:Fire(player, "Sfx", "Denied")
		return
	end
	data.Weapons[weapon.Id] = true
	player:SetAttribute("Weapon_" .. weapon.Id, true)
	CombatService:RefreshWeapons(player)
	Net:Notify(player, ("Unlocked the %s! It's yours forever."):format(weapon.DisplayName), "success")
	Net:Fire(player, "Sfx", "Purchase")
	Net:Fire(player, "Fx", "Confetti")
end

local function setPvP(player, on)
	if type(on) ~= "boolean" or player:GetAttribute("PvP") == on then
		return
	end
	if not on and os.clock() - (lastCombat[player] or 0) < WeaponConfig.PvPCombatLock then
		Net:Notify(player, "You're in combat! Wait a few seconds before turning PvP off.", "error")
		return
	end
	player:SetAttribute("PvP", on)
	Net:Notify(player, if on then "⚔️ PvP ON: you can fight other PvP players anywhere." else "🛡️ PvP OFF: you're safe outside the arena.", if on then "error" else "success")
end

local function setupPlayer(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	player:SetAttribute("PvP", false)
	for _, weapon in ipairs(WeaponConfig.Weapons) do
		player:SetAttribute("Weapon_" .. weapon.Id, data.Weapons[weapon.Id] == true)
	end

	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Once(function()
				onDied(player, player:GetAttribute("InArena") == true)
			end)
		end
		task.wait() -- the new Backpack arrives with the character
		CombatService:RefreshWeapons(player)
		updateTag(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	for _, attribute in ipairs({ "InArena", "PvP" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			CombatService:RefreshWeapons(player)
			updateTag(player)
		end)
	end
	-- Owning a Prototype unlocks the Prototype Cannon
	player:GetAttributeChangedSignal("Prototypes"):Connect(function()
		CombatService:RefreshWeapons(player)
	end)
end

-- Re-checks everyone's weapons (e.g. when a boss raid starts or ends)
function CombatService:RefreshAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") then
			self:RefreshWeapons(player)
		end
	end
end

function CombatService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	ArenaService = services.ArenaService
	Net = services.Net
end

function CombatService:Start()
	PlayerService.PlayerReady:Connect(setupPlayer)
	Net:On("BuyWeapon", buyWeapon, 1, 2)
	Net:On("SetPvP", setPvP, 0.5, 2)
	Net:On("FireWeapon", fireWeapon, 8, 10)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastCombat[player] = nil
		cooldowns[player] = nil
	end)
end

return CombatService
