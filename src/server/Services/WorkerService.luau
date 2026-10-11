--[[
	WorkerService
	Spend robots (built by your factory) to hire worker bots. Each bot stands
	on your plot and gives a permanent boost defined in WorkerConfig.

	Saved as data.Workers = { [workerId] = count }.
	Mirrored to the client as attributes Worker_<id> = count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorkerConfig = require(Shared.Config.WorkerConfig)

local DataService, EconomyService, PlotService, PlayerService, QuestService, Net

local WorkerService = {}

local workersById = {}
for _, worker in ipairs(WorkerConfig.Workers) do
	workersById[worker.Id] = worker
end

local function getCount(data, workerId)
	return tonumber(data.Workers[workerId]) or 0
end

local function buildBot(worker, slotCFrame)
	local model = Instance.new("Model")
	model.Name = worker.Id

	local function part(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = slotCFrame * offset
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local steel = Color3.fromRGB(190, 195, 205)
	local body = part("Body", Vector3.new(2, 2, 1.4), CFrame.new(0, 2.2, 0), worker.Color)
	part("Legs", Vector3.new(1.4, 1.2, 1), CFrame.new(0, 0.6, 0), Color3.fromRGB(60, 62, 68))
	part("Head", Vector3.new(1.5, 1.2, 1.2), CFrame.new(0, 3.8, 0), steel)
	-- Bots face +Z (toward the belt and the entrance)
	part("Eyes", Vector3.new(1.1, 0.3, 0.1), CFrame.new(0, 3.9, 0.62), Color3.fromRGB(0, 255, 255), Enum.Material.Neon)
	part("Antenna", Vector3.new(0.2, 0.8, 0.2), CFrame.new(0, 4.8, 0), steel)
	part("AntennaTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 5.3, 0), worker.Color, Enum.Material.Neon)
	model.PrimaryPart = body

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(110, 24)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.MaxDistance = 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = worker.Icon .. " " .. worker.DisplayName
	label.Parent = billboard
	billboard.Parent = body

	return model
end

-- Rebuilds the bot models on the player's plot to match their saved counts.
local function renderWorkers(player)
	local data = DataService:GetData(player)
	local plot = PlotService:GetPlot(player)
	if not (data and plot) then
		return
	end

	local folder = plot.Model.Workers
	folder:ClearAllChildren()

	for _, worker in ipairs(WorkerConfig.Workers) do
		local count = math.min(getCount(data, worker.Id), #worker.Slots)
		for index = 1, count do
			local slotCFrame = plot.CFrame * CFrame.new(worker.Slots[index])
			buildBot(worker, slotCFrame).Parent = folder
		end
		player:SetAttribute("Worker_" .. worker.Id, getCount(data, worker.Id))
	end
end

local function hire(player, workerId)
	local worker = type(workerId) == "string" and workersById[workerId]
	local data = DataService:GetData(player)
	if not (worker and data) then
		return
	end

	local count = getCount(data, worker.Id)
	if count >= #worker.Slots then
		Net:Notify(player, worker.DisplayName .. " is maxed out.", "error")
		return
	end
	if data.Robots < worker.Cost then
		Net:Notify(player, ("You need %d robots to hire a %s."):format(worker.Cost, worker.DisplayName), "error")
		return
	end

	EconomyService:AddStat(player, "Robots", -worker.Cost)
	data.Workers[worker.Id] = count + 1
	renderWorkers(player)
	Net:Fire(player, "Sfx", "Purchase")
	QuestService:Track(player, "WorkersHired", 1)
	Net:Notify(player, ("Hired a %s! %s"):format(worker.DisplayName, worker.Description), "success")
end

local function dismiss(player, workerId)
	local worker = type(workerId) == "string" and workersById[workerId]
	local data = DataService:GetData(player)
	if not (worker and data) then
		return
	end

	local count = getCount(data, worker.Id)
	if count <= 0 then
		return
	end
	data.Workers[worker.Id] = count - 1
	renderWorkers(player)
	Net:Notify(player, "Dismissed a " .. worker.DisplayName .. ".", "info")
end

function WorkerService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	Net = services.Net
end

function WorkerService:Start()
	PlayerService.PlayerReady:Connect(renderWorkers)
	Net:On("HireWorker", hire, 3, 5)
	Net:On("DismissWorker", dismiss, 3, 5)
end

-- 1 + every DropperSpeed bonus
function WorkerService:GetDropperSpeedMultiplier(player: Player): number
	local data = DataService:GetData(player)
	local multiplier = 1
	if data then
		for _, worker in ipairs(WorkerConfig.Workers) do
			if worker.Effect.Type == "DropperSpeed" then
				multiplier += getCount(data, worker.Id) * worker.Effect.Amount
			end
		end
	end
	return multiplier
end

-- 1 + every MachineValue bonus that applies to this machine
function WorkerService:GetMachineMultiplier(player: Player, machineId: string): number
	local data = DataService:GetData(player)
	local multiplier = 1
	if data then
		for _, worker in ipairs(WorkerConfig.Workers) do
			local effect = worker.Effect
			if effect.Type == "MachineValue" and (effect.Machine == machineId or effect.Machine == "*") then
				multiplier += getCount(data, worker.Id) * effect.Amount
			end
		end
	end
	return multiplier
end

return WorkerService
