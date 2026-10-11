--[[
	EventService
	Random server-wide events (EventConfig). One event at a time; the
	active event is published as workspace attributes so every client can
	show a banner:
	  Event        = event id ("" when none)
	  EventEndsAt  = workspace:GetServerTimeNow() when it ends
	Other services ask GetValue(key, default) for the active event's settings.

	Malfunction: one built machine in every claimed factory starts sparking.
	Its owner (or co-op builders) clicks it ClicksToFix times before the
	event ends to fix it and earn a reward. Until then that machine adds
	less value (ProductionService reads IsBroken).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local EconomyService, DataService, PlotService, CoopService, Net

local EventService = {}
EventService.Changed = require(Shared.Util.Signal).new()

local active -- event config table or nil
local activeId = ""
local activeToken = 0 -- so an old event's timer can't end a newer event
local broken = {} -- [machine Model] = { Owner, Clicks, Effects = { Instance } }

function EventService:GetActive()
	return activeId, active
end

function EventService:GetValue(key: string, default)
	if active and active[key] ~= nil then
		return active[key]
	end
	return default
end

-- Is this machine model sparking from a Malfunction?
function EventService:IsBroken(model): boolean
	return broken[model] ~= nil
end

local function refreshPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService:Refresh(player)
	end
end

-- Malfunction ----------------------------------------------------------------------

local function repair(model)
	local entry = broken[model]
	if not entry then
		return
	end
	broken[model] = nil
	for _, effect in ipairs(entry.Effects) do
		effect:Destroy()
	end
end

local function breakMachine(owner, model, settings)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local entry = { Owner = owner, Clicks = 0, LastClick = {}, Effects = {} }
	broken[model] = entry

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "MalfunctionSparks"
	sparks.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 80, 20))
	sparks.Parent = root
	local smoke = Instance.new("Smoke")
	smoke.Name = "MalfunctionSmoke"
	smoke.Color = Color3.fromRGB(60, 60, 60)
	smoke.RiseVelocity = 6
	smoke.Parent = root

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FixMe"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 60)
	label.TextStrokeTransparency = 0
	label.Text = ("🔧 CLICK TO FIX! 0/%d"):format(settings.ClicksToFix)
	label.Parent = billboard
	billboard.Parent = root

	-- Every part of the machine is clickable/tappable
	local detector = Instance.new("ClickDetector")
	detector.Name = "FixDetector"
	detector.MaxActivationDistance = 60
	detector.Parent = model
	table.insert(entry.Effects, sparks)
	table.insert(entry.Effects, smoke)
	table.insert(entry.Effects, billboard)
	table.insert(entry.Effects, detector)

	detector.MouseClick:Connect(function(clicker)
		if broken[model] ~= entry or not CoopService:CanBuild(clicker, owner) then
			return
		end
		-- Clicks are capped at 12 per second so auto-clickers don't help much
		local now = os.clock()
		if now - (entry.LastClick[clicker] or 0) < 1 / 12 then
			return
		end
		entry.LastClick[clicker] = now
		entry.Clicks += 1
		label.Text = ("🔧 CLICK TO FIX! %d/%d"):format(entry.Clicks, settings.ClicksToFix)
		if entry.Clicks >= settings.ClicksToFix then
			repair(model)
			local data = owner.Parent and DataService:GetData(owner)
			if data then
				local cash = settings.RewardCash * RebirthConfig.GetMultiplier(data.Rebirths)
				EconomyService:AddCash(owner, cash)
				Net:Notify(owner, "🔧 Machine fixed! +" .. Format.cash(cash), "success")
				Net:Fire(owner, "Sfx", "Purchase")
				Net:Fire(owner, "Fx", "Upgrade", root.Position)
			end
		end
	end)
end

local function startMalfunction(settings)
	for _, plot in ipairs(PlotService:GetPlots()) do
		local owner = plot.Owner
		if owner then
			local machines = {}
			for _, model in ipairs(plot.Model.Items:GetChildren()) do
				if model:FindFirstChild("Zone", true) then
					table.insert(machines, model)
				end
			end
			if #machines > 0 then
				breakMachine(owner, machines[math.random(#machines)], settings)
			end
		end
	end
end

local function endMalfunction()
	for model, entry in pairs(broken) do
		repair(model)
		if entry.Owner.Parent and model.Parent then
			Net:Notify(entry.Owner, "The broken machine was repaired by the factory crew... no reward this time.", "info")
		end
	end
end

-- Events ---------------------------------------------------------------------------

function EventService:StartEvent(id: string)
	local event = EventConfig.Events[id]
	if not event then
		return false
	end
	if active and active.Malfunction then
		endMalfunction()
	end
	active, activeId = event, id
	activeToken += 1
	local token = activeToken
	local duration = event.Duration or 30
	workspace:SetAttribute("Event", id)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + duration)
	Net:NotifyAll(event.DisplayName .. "! " .. event.Description, "special")
	Net:FireAll("Sfx", "Event")
	refreshPlayers()
	if event.Malfunction then
		startMalfunction(event.Malfunction)
	end
	self.Changed:Fire(id)

	task.delay(duration, function()
		if activeToken == token then
			if event.Malfunction then
				endMalfunction()
			end
			active, activeId = nil, ""
			workspace:SetAttribute("Event", "")
			refreshPlayers()
			self.Changed:Fire("")
		end
	end)
	return true
end

function EventService:Init(services)
	EconomyService = services.EconomyService
	DataService = services.DataService
	PlotService = services.PlotService
	CoopService = services.CoopService
	Net = services.Net
	workspace:SetAttribute("Event", "")
end

function EventService:Start()
	PlotService.PlotReleased:Connect(function(player)
		for model, entry in pairs(broken) do
			if entry.Owner == player then
				broken[model] = nil
			end
		end
	end)

	task.spawn(function()
		task.wait(EventConfig.FirstDelay)
		local ids = {}
		for id in pairs(EventConfig.Events) do
			table.insert(ids, id)
		end
		table.sort(ids)
		while true do
			local waitFor = 10
			if #Players:GetPlayers() > 0 then
				local id = ids[math.random(#ids)]
				self:StartEvent(id)
				waitFor = (EventConfig.Events[id].Duration or 30) + math.random(EventConfig.Interval[1], EventConfig.Interval[2])
			end
			task.wait(waitFor)
		end
	end)
end

return EventService
