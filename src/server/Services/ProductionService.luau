--[[
	ProductionService
	Makes the factory run: droppers spawn items, belts carry them, machines
	upgrade them, and the collector turns them into cash on the cash pad.

	Server-authoritative: each item's value and stage live in a server-side
	record. Attributes on the part are for display only. Items are physics
	parts owned by the server (SetNetworkOwner(nil)), so clients can't move them.

	Lag control:
	  * each plot holds at most ProductionConfig.MaxDropsPerPlot items (droppers pause)
	  * every item is given to Debris with DropLifetime as a safety net
	  * items that fall off the plot are destroyed
	  * one throttled Heartbeat loop (20 Hz) handles every plot's items
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProductionConfig = require(Shared.Config.ProductionConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Format = require(Shared.Util.Format)

local EconomyService, TycoonService, PlotService, PlayerService, WorkerService, Net
local EventService, UpgradeService, RobotBookService, QuestService, MiningService, CoopService
local BoostService, CosmeticService

local Stages = ProductionConfig.Stages
local UPDATE_INTERVAL = 1 / 20

local ProductionService = {}

--[[
	plotStates[player] = {
		Player, Plot,
		Drops = { [Part] = record }, DropCount,
		Machines = { { Item, Zone, Model } }, Intakes = { Part }, Belts = { Part },
		ConveyorMultiplier, Assembly = { [machineId] = { Count, Value, Color } },
		ForcePrototype,
	}
	record = { Part, Value, Stage, Visited = { [machineId] = true }, Color?, Prototype? }
]]
local plotStates = {}

-- Helpers ------------------------------------------------------------------

local function isInside(part, position)
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function isCurrent(player, st)
	return plotStates[player] == st
end

local function getState(player, plot)
	local st = plotStates[player]
	if not st or st.Plot ~= plot then
		st = {
			Player = player,
			Plot = plot,
			Drops = {},
			DropCount = 0,
			Machines = {},
			Intakes = {},
			Belts = {},
			ConveyorMultiplier = 1,
			Assembly = {},
			ForcePrototype = false,
		}
		plotStates[player] = st
	end
	return st
end

local function pulse(part)
	if not (part and part.Parent) then
		return
	end
	local base = part:GetAttribute("BaseTransparency")
	if base == nil then
		base = part.Transparency
		part:SetAttribute("BaseTransparency", base)
	end
	part.Transparency = if base < 0.3 then base + 0.6 else base - 0.4
	TweenService:Create(part, TweenInfo.new(0.3), { Transparency = base }):Play()
end

-- Belts --------------------------------------------------------------------

local function refreshBelts(st)
	if not st then
		return
	end
	local speed = ProductionConfig.BeltSpeed * st.ConveyorMultiplier * EventService:GetValue("BeltMultiplier", 1)
	if st.Player:GetAttribute("Pass_FasterConveyors") then
		speed *= MonetizationConfig.FasterConveyorMultiplier
	end

	-- An anchored part with velocity carries whatever sits on it.
	-- The MovingArrows tag makes clients draw arrows sliding along it.
	for _, belt in ipairs(st.Belts) do
		if belt.Parent then
			belt.AssemblyLinearVelocity = belt.CFrame.RightVector * speed
			belt:SetAttribute("Direction", 1)
			belt:SetAttribute("Speed", speed)
			belt:SetAttribute("Color", Color3.fromRGB(255, 200, 40))
			CollectionService:AddTag(belt, "MovingArrows")
		end
	end
end

-- Items ----------------------------------------------------------------------

local function addRobotDetails(body, prototype, rarity)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 0.9, 1)
	head.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2 + 0.45, 0)
	head.Color = Color3.fromRGB(200, 205, 215)
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true

	local eyes = Instance.new("Part")
	eyes.Name = "Eyes"
	eyes.Size = Vector3.new(0.9, 0.25, 0.1)
	eyes.CFrame = head.CFrame * CFrame.new(0, 0.1, -0.5)
	eyes.Color = if prototype then Color3.fromRGB(255, 60, 255) elseif rarity then rarity.Color else Color3.fromRGB(0, 255, 255)
	eyes.Material = Enum.Material.Neon
	eyes.CanCollide = false
	eyes.Massless = true

	for _, part in ipairs({ head, eyes }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = body
	end

	-- Rarity: colored head, glow for Rare+, sparkles and a tag for Epic+
	if rarity and not prototype and rarity.Id ~= "Common" then
		head.Color = rarity.Color
		if rarity.ValueMultiplier >= 2.5 then
			head.Material = Enum.Material.Neon
			local light = Instance.new("PointLight")
			light.Color = rarity.Color
			light.Range = 8
			light.Parent = head
		end
		if rarity.ValueMultiplier >= 5 then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = rarity.Color
			sparkles.Parent = body
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(110, 26)
			tag.StudsOffset = Vector3.new(0, 2.8, 0)
			tag.MaxDistance = 80
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.Sarpanch
			text.TextScaled = true
			text.TextColor3 = rarity.Color
			text.TextStrokeTransparency = 0
			text.Text = string.upper(rarity.Id)
			text.Parent = tag
			tag.Parent = body
		end
	end

	if prototype then
		body.Material = Enum.Material.Neon
		body.Color = Color3.fromRGB(150, 60, 255)
		head.Material = Enum.Material.Neon
		head.Color = Color3.fromRGB(80, 220, 255)

		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 120, 255)
		sparkles.Parent = body

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(200, 120, 255)
		light.Range = 12
		light.Brightness = 3
		light.Parent = body

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(120, 30)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 150, 255)
		label.TextStrokeTransparency = 0
		label.Text = "★ PROTOTYPE ★"
		label.Parent = billboard
		billboard.Parent = body
	end
end

-- Sky Factory robot types: bigger, recolored, with a name tag
local function applyRobotType(part, robotType)
	local style = ProductionConfig.RobotTypes[robotType]
	if not style then
		return
	end
	part.Size = Stages.Robot.Size * style.Scale
	part.Color = style.Color
	part.Material = style.Material
	part:SetAttribute("RobotType", robotType)
	local old = part:FindFirstChild("TypeTag")
	if old then
		old:Destroy()
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "TypeTag"
	tag.Size = UDim2.fromOffset(120, 24)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 70
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Sarpanch
	text.TextScaled = true
	text.TextColor3 = style.Color
	text.TextStrokeTransparency = 0
	text.Text = style.Name
	text.Parent = tag
	tag.Parent = part
end

-- Creates an item part. Returns its record, or nil when the plot is full.
-- `force` skips the per-plot cap (used for robots so finished work isn't lost).
local function createDrop(st, stage, value, cframe, options)
	options = options or {}
	if st.DropCount >= ProductionConfig.MaxDropsPerPlot and not options.Force then
		return nil
	end

	local style = Stages[stage]
	local part = Instance.new("Part")
	part.Name = if options.Prototype then "Prototype" else stage
	part.Size = style.Size
	part.Material = style.Material
	part.Color = options.Color or style.Color
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1, 0.05)
	part:SetAttribute("Stage", stage)
	part:SetAttribute("Value", value)

	if stage == "Robot" then
		addRobotDetails(part, options.Prototype, options.Rarity)
		if options.RobotType then
			applyRobotType(part, options.RobotType)
		end
		if options.Skin and not options.Prototype then
			-- Robot skin cosmetic (CosmeticConfig.Skins): recolors the body, rarity eyes stay
			part.Color = options.Skin.Color
			part.Material = options.Skin.Material or part.Material
			if options.Skin.Glow then
				local light = Instance.new("PointLight")
				light.Color = options.Skin.Color
				light.Range = 6
				light.Parent = part
			end
		end
	end
	if options.Golden then
		part.Name = "Golden" .. stage
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Material = Enum.Material.Neon
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 80)
		sparkles.Parent = part
	end

	local record = {
		Part = part,
		Value = value,
		Stage = stage,
		Visited = options.Visited or {},
		Color = options.Color,
		PaintName = options.PaintName,
		Prototype = options.Prototype,
		Rarity = options.Rarity,
		Golden = options.Golden,
		RobotType = options.RobotType,
	}

	part.Parent = st.Plot.Model.Drops
	pcall(part.SetNetworkOwner, part, nil)
	Debris:AddItem(part, ProductionConfig.DropLifetime)

	st.Drops[part] = record
	st.DropCount += 1
	part.Destroying:Connect(function()
		if st.Drops[part] then
			st.Drops[part] = nil
			st.DropCount -= 1
		end
	end)

	return record
end

local function startDropper(player, st, item, model)
	local spout = model:FindFirstChild("Spout", true)
	if not spout then
		warn(("[Production] %s has no part named 'Spout'"):format(item.Id))
		return
	end

	local config = item.Dropper
	local stage = config.Stage or "Scrap"
	local size = Stages[stage].Size

	task.spawn(function()
		while model.Parent and isCurrent(player, st) do
			local _, speedBoost = UpgradeService:GetDropperBoosts(player, item.Id)
			local speed = WorkerService:GetDropperSpeedMultiplier(player)
				* speedBoost
				* EventService:GetValue("DropperMultiplier", 1)
				* BoostService:GetValue(player, "DropperMultiplier", 1)
			task.wait(config.Interval / speed)
			if not (model.Parent and isCurrent(player, st)) then
				break
			end
			if #st.Intakes == 0 then
				continue -- nothing to collect into yet (e.g. right after a rebirth)
			end

			local jitter = Vector3.new((math.random() - 0.5) * 0.6, 0, (math.random() - 0.5) * 0.6)
			local position = spout.Position - Vector3.new(0, spout.Size.Y / 2 + size.Y / 2 + 0.1, 0) + jitter
			local value = config.Value * (UpgradeService:GetDropperBoosts(player, item.Id))
			local golden = math.random() < EventService:GetValue("GoldenChance", 0)
			if golden then
				value *= EventService:GetValue("GoldenMultiplier", 1)
			end
			if createDrop(st, stage, value, CFrame.new(position) * st.Plot.CFrame.Rotation, { Golden = golden }) then
				pulse(spout)
			end
		end
	end)
end

local function spawnRobot(player, st, machine, value, color, paintName, visited)
	if not (isCurrent(player, st) and machine.Zone.Parent) then
		return
	end

	local chance = ProductionConfig.PrototypeChance * BoostService:GetValue(player, "PrototypeChanceMultiplier", 1)
	local prototype = st.ForcePrototype or math.random() < chance
	st.ForcePrototype = false
	if prototype then
		value *= ProductionConfig.PrototypeValueMultiplier
		Net:Notify(player, "A PROTOTYPE robot just rolled off your line!", "special")
	end

	local rarity = RobotBookService:RollRarity()
	value *= rarity.ValueMultiplier
	local robotType = machine.Item.Machine.RobotType
	if robotType and ProductionConfig.RobotTypes[robotType] then
		value *= ProductionConfig.RobotTypes[robotType].ValueMultiplier
	end

	local zone = machine.Zone
	createDrop(st, "Robot", value, zone.CFrame * CFrame.new(zone.Size.X / 2 + 1.2, 0, 0), {
		Force = true,
		Skin = if robotType then nil else CosmeticService:GetSkin(player),
		RobotType = robotType,
		Color = color,
		PaintName = paintName,
		Prototype = prototype,
		Rarity = rarity,
		Visited = visited,
	})
end

-- Machines and collecting ----------------------------------------------------

local function process(player, st, machine, record)
	local config = machine.Item.Machine
	if not table.find(config.Accepts, record.Stage) then
		return
	end

	local multiplier = (config.Multiplier or 1)
		* WorkerService:GetMachineMultiplier(player, machine.Item.Id)
		* UpgradeService:GetMachineMultiplier(player, machine.Item.Id)
		* MiningService:GetMachineMultiplier(player)
	if EventService:IsBroken(machine.Model) then
		multiplier *= EventService:GetValue("Malfunction", {}).BrokenValueMultiplier or 0.5
	end
	local part = record.Part
	pulse(machine.Glow)

	-- Final Assembly: absorb parts, release one robot every PartsPerRobot
	if config.PartsPerRobot then
		local buffer = st.Assembly[machine.Item.Id] or { Count = 0, Value = 0 }
		st.Assembly[machine.Item.Id] = buffer
		buffer.Count += 1
		buffer.Value += record.Value
		buffer.Color = record.Color or buffer.Color
		buffer.PaintName = record.PaintName or buffer.PaintName
		part:Destroy()

		local needed = EventService:GetValue("PartsPerRobot", config.PartsPerRobot)
		if buffer.Count >= needed then
			st.Assembly[machine.Item.Id] = nil
			-- Deferred: we're in the middle of looping over this plot's items
			task.defer(
				spawnRobot,
				player,
				st,
				machine,
				buffer.Value * multiplier,
				buffer.Color,
				buffer.PaintName,
				table.clone(record.Visited)
			)
		end
		return
	end

	record.Value *= multiplier

	-- Robot upgraders (Quantum Assembler): finished robots become a new type
	if config.RobotType and record.Stage == "Robot" and ProductionConfig.RobotTypes[config.RobotType] then
		record.Value *= ProductionConfig.RobotTypes[config.RobotType].ValueMultiplier
		record.RobotType = config.RobotType
		applyRobotType(part, config.RobotType)
	end

	if config.Output then
		local style = Stages[config.Output]
		record.Stage = config.Output
		part.Name = config.Output
		part.Size = style.Size
		if not record.Golden then
			part.Material = style.Material
			part.Color = record.Color or style.Color
		end
	end

	if config.Paint then
		local paint = ProductionConfig.PaintColors[math.random(#ProductionConfig.PaintColors)]
		record.Color = paint.Color
		record.PaintName = paint.Name
		part.Color = paint.Color
		part.Reflectance = 0.15
		QuestService:Track(player, "ItemsPainted", 1)
	end

	part:SetAttribute("Stage", record.Stage)
	part:SetAttribute("Value", record.Value)
end

local function collect(player, st, record)
	record.Part:Destroy()
	EconomyService:Earn(player, record.Value)

	if record.Stage == "Robot" then
		EconomyService:AddStat(player, "Robots", 1)
		EconomyService:AddStat(player, "RobotsBuilt", 1)
		QuestService:Track(player, "RobotsSold", 1)
		if record.Rarity then
			RobotBookService:Record(player, record.Rarity.Id, record.PaintName or "Steel")
		end
		if record.Prototype then
			EconomyService:AddStat(player, "Prototypes", 1)
			Net:NotifyAll(player.DisplayName .. " built a ★ PROTOTYPE ★ robot!", "special")
		end
		-- Big sale: confetti and a little screen shake for Prototypes and Epic+ robots
		if record.Prototype or (record.Rarity and record.Rarity.ValueMultiplier >= 5) then
			Net:Fire(player, "Fx", "BigSale", record.Part.Position)
		end
	end

	for _, intake in ipairs(st.Intakes) do
		pulse(intake)
	end
end

local function step()
	for player, st in pairs(plotStates) do
		local floorY = st.Plot.CFrame.Y - 15

		for part, record in pairs(st.Drops) do
			if part.Parent then
				local position = part.Position

				if position.Y < floorY then
					part:Destroy()
				else
					local collected = false
					for _, intake in ipairs(st.Intakes) do
						if intake.Parent and isInside(intake, position) then
							collect(player, st, record)
							collected = true
							break
						end
					end

					if not collected then
						for _, machine in ipairs(st.Machines) do
							local id = machine.Item.Id
							if not record.Visited[id] and machine.Zone.Parent and isInside(machine.Zone, position) then
								record.Visited[id] = true
								process(player, st, machine, record)
								if not part.Parent then
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Cash pad -------------------------------------------------------------------

local function setupCashPad(player, st, pad)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CashDisplay"
	billboard.Size = UDim2.fromOffset(200, 70)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 80

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.4)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.2
	title.Text = "Step here to collect"
	title.Parent = billboard

	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.fromScale(0, 0.4)
	amount.Size = UDim2.fromScale(1, 0.6)
	amount.Font = Enum.Font.FredokaOne
	amount.TextScaled = true
	amount.TextColor3 = Color3.fromRGB(120, 255, 140)
	amount.TextStrokeTransparency = 0.2
	amount.Parent = billboard
	billboard.Parent = pad

	local function update()
		if player:GetAttribute("Pass_AutoCollect") then
			title.Text = "Auto-Collect is on"
			amount.Text = "🧲"
		else
			title.Text = "Step here to collect"
			amount.Text = Format.cash(player:GetAttribute("PendingCash") or 0)
		end
	end
	update()

	local connections = {
		player:GetAttributeChangedSignal("PendingCash"):Connect(update),
		player:GetAttributeChangedSignal("Pass_AutoCollect"):Connect(update),
	}
	pad.Destroying:Connect(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)

	local lastTouch = 0
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local toucher = character and Players:GetPlayerFromCharacter(character)
		-- The owner, or a co-op builder (cash still goes to the owner)
		if not toucher or not CoopService:CanBuild(toucher, player) or not isCurrent(player, st) then
			return
		end
		local now = os.clock()
		if now - lastTouch < ProductionConfig.CashPadCooldown then
			return
		end
		lastTouch = now

		local collected = EconomyService:CollectPending(player)
		if collected > 0 then
			Net:Fire(player, "CashPopup", collected)
			Net:Fire(player, "Sfx", "Cash")
			Net:Fire(player, "Fx", "Coins", pad.Position)
			QuestService:Track(player, "PadCollects", 1)
			pulse(pad)
		end
	end)
end

-- Wiring ---------------------------------------------------------------------

local function onItemUnlocked(player, plot, item, model)
	local st = getState(player, plot)

	if item.Conveyor then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "Belt" then
				table.insert(st.Belts, descendant)
			end
		end
		st.ConveyorMultiplier = math.max(st.ConveyorMultiplier, item.Conveyor.SpeedMultiplier or 1)
		refreshBelts(st)
	end

	if item.Dropper then
		startDropper(player, st, item, model)
	end

	if item.Machine then
		local zone = model:FindFirstChild("Zone", true)
		if zone then
			table.insert(st.Machines, { Item = item, Zone = zone, Model = model, Glow = model:FindFirstChild("Glow", true) })
		else
			warn(("[Production] Machine %s has no part named 'Zone'"):format(item.Id))
		end
	end

	if item.Collector then
		local intake = model:FindFirstChild("Intake", true)
		if intake then
			table.insert(st.Intakes, intake)
		else
			warn(("[Production] Collector %s has no part named 'Intake'"):format(item.Id))
		end
		local pad = model:FindFirstChild("CashPad", true)
		if pad then
			setupCashPad(player, st, pad)
		end
	end
end

function ProductionService:Init(services)
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	WorkerService = services.WorkerService
	Net = services.Net
	EventService = services.EventService
	UpgradeService = services.UpgradeService
	RobotBookService = services.RobotBookService
	QuestService = services.QuestService
	MiningService = services.MiningService
	CoopService = services.CoopService
	BoostService = services.BoostService
	CosmeticService = services.CosmeticService
end

function ProductionService:Start()
	TycoonService.ItemUnlocked:Connect(onItemUnlocked)

	-- Rebirth or leaving: drop the state so dropper loops stop
	TycoonService.TycoonReset:Connect(function(player)
		plotStates[player] = nil
	end)
	PlotService.PlotReleased:Connect(function(player)
		plotStates[player] = nil
	end)

	PlayerService.PlayerReady:Connect(function(player)
		player:GetAttributeChangedSignal("Pass_FasterConveyors"):Connect(function()
			refreshBelts(plotStates[player])
		end)
	end)

	-- Power Surge changes belt speed for everyone
	EventService.Changed:Connect(function()
		for _, st in pairs(plotStates) do
			refreshBelts(st)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= UPDATE_INTERVAL then
			elapsed = 0
			step()
		end
	end)
end

-- Studio testing: the next robot this player builds is a Prototype.
function ProductionService:ForcePrototype(player: Player)
	local st = plotStates[player]
	if st then
		st.ForcePrototype = true
	end
end

function ProductionService:GetDropCount(player: Player): number
	local st = plotStates[player]
	return st and st.DropCount or 0
end

return ProductionService
