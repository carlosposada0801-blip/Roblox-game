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
	local speed = ProductionConfig.BeltSpeed * st.ConveyorMultiplier
	if st.Player:GetAttribute("Pass_FasterConveyors") then
		speed *= MonetizationConfig.FasterConveyorMultiplier
	end

	-- An anchored part with velocity carries whatever sits on it.
	for _, belt in ipairs(st.Belts) do
		if belt.Parent then
			belt.AssemblyLinearVelocity = belt.CFrame.RightVector * speed
		end
	end
end

-- Items ----------------------------------------------------------------------

local function addRobotDetails(body, prototype)
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
	eyes.Color = if prototype then Color3.fromRGB(255, 60, 255) else Color3.fromRGB(0, 255, 255)
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
		addRobotDetails(part, options.Prototype)
	end

	local record = {
		Part = part,
		Value = value,
		Stage = stage,
		Visited = options.Visited or {},
		Color = options.Color,
		Prototype = options.Prototype,
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
			task.wait(config.Interval / WorkerService:GetDropperSpeedMultiplier(player))
			if not (model.Parent and isCurrent(player, st)) then
				break
			end
			if #st.Intakes == 0 then
				continue -- nothing to collect into yet (e.g. right after a rebirth)
			end

			local jitter = Vector3.new((math.random() - 0.5) * 0.6, 0, (math.random() - 0.5) * 0.6)
			local position = spout.Position - Vector3.new(0, spout.Size.Y / 2 + size.Y / 2 + 0.1, 0) + jitter
			if createDrop(st, stage, config.Value, CFrame.new(position) * st.Plot.CFrame.Rotation) then
				pulse(spout)
			end
		end
	end)
end

local function spawnRobot(player, st, machine, value, color, visited)
	if not (isCurrent(player, st) and machine.Zone.Parent) then
		return
	end

	local prototype = st.ForcePrototype or math.random() < ProductionConfig.PrototypeChance
	st.ForcePrototype = false
	if prototype then
		value *= ProductionConfig.PrototypeValueMultiplier
		Net:Notify(player, "A PROTOTYPE robot just rolled off your line!", "special")
	end

	local zone = machine.Zone
	createDrop(st, "Robot", value, zone.CFrame * CFrame.new(zone.Size.X / 2 + 1.2, 0, 0), {
		Force = true,
		Color = color,
		Prototype = prototype,
		Visited = visited,
	})
end

-- Machines and collecting ----------------------------------------------------

local function process(player, st, machine, record)
	local config = machine.Item.Machine
	if not table.find(config.Accepts, record.Stage) then
		return
	end

	local multiplier = (config.Multiplier or 1) * WorkerService:GetMachineMultiplier(player, machine.Item.Id)
	local part = record.Part
	pulse(machine.Glow)

	-- Final Assembly: absorb parts, release one robot every PartsPerRobot
	if config.PartsPerRobot then
		local buffer = st.Assembly[machine.Item.Id] or { Count = 0, Value = 0 }
		st.Assembly[machine.Item.Id] = buffer
		buffer.Count += 1
		buffer.Value += record.Value
		buffer.Color = record.Color or buffer.Color
		part:Destroy()

		if buffer.Count >= config.PartsPerRobot then
			st.Assembly[machine.Item.Id] = nil
			-- Deferred: we're in the middle of looping over this plot's items
			task.defer(spawnRobot, player, st, machine, buffer.Value * multiplier, buffer.Color, table.clone(record.Visited))
		end
		return
	end

	record.Value *= multiplier

	if config.Output then
		local style = Stages[config.Output]
		record.Stage = config.Output
		part.Name = config.Output
		part.Size = style.Size
		part.Material = style.Material
		part.Color = record.Color or style.Color
	end

	if config.Paint then
		local color = ProductionConfig.PaintColors[math.random(#ProductionConfig.PaintColors)]
		record.Color = color
		part.Color = color
		part.Reflectance = 0.15
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
		if record.Prototype then
			EconomyService:AddStat(player, "Prototypes", 1)
			Net:NotifyAll(player.DisplayName .. " built a ★ PROTOTYPE ★ robot!", "special")
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
		if not character or Players:GetPlayerFromCharacter(character) ~= player or not isCurrent(player, st) then
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
			table.insert(st.Machines, { Item = item, Zone = zone, Glow = model:FindFirstChild("Glow", true) })
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
