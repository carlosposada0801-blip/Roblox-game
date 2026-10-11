--[[
	RaceService
	Robot races on a floating track (RaceConfig). Players enter their race
	bot from the Race menu (RaceAction "Join"); every EntryWindow seconds a
	race runs with everyone who joined plus AI bots to fill the lanes.
	Bot speed = base + level bonus + random wobble each second.
	Upgrade your bot with robots (RaceAction "Upgrade").
	workspace attributes: RaceState ("Waiting"/"Racing"), RaceStartsAt, RaceEntrants
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceConfig = require(Shared.Config.RaceConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)
local Portal = require(script.Parent.Parent.Util.Portal)

local DataService, EconomyService, Net

local RaceService = {}

local entrants = {} -- array of players
local AI_NAMES = { "Rusty", "Sparky", "Zoom-3000", "Bolt Jr.", "Turbo", "Gizmo" }
local AI_COLORS = { Color3.fromRGB(150, 150, 160), Color3.fromRGB(200, 120, 60), Color3.fromRGB(90, 160, 90), Color3.fromRGB(120, 120, 200) }

local trackFolder, startX, laneZ

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

local function buildTrack()
	trackFolder = Instance.new("Folder")
	trackFolder.Name = "RaceTrack"
	trackFolder.Parent = workspace
	local center = RaceConfig.Center
	local width = RaceConfig.Lanes * 8 + 4
	local length = RaceConfig.Length + 40
	startX = center.X - RaceConfig.Length / 2
	laneZ = {}

	part({ Name = "Track", Size = Vector3.new(length, 2, width), CFrame = CFrame.new(center - Vector3.new(0, 1, 0)), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.Asphalt }, trackFolder)
	for lane = 1, RaceConfig.Lanes do
		local z = center.Z - width / 2 + 2 + (lane - 0.5) * 8
		laneZ[lane] = z
		part({ Name = "LaneLine", Size = Vector3.new(length, 0.05, 0.3), CFrame = CFrame.new(center.X, center.Y + 0.03, z + 4), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false }, trackFolder)
	end
	-- Start and finish lines
	part({ Name = "StartLine", Size = Vector3.new(1, 0.06, width), CFrame = CFrame.new(startX, center.Y + 0.04, center.Z), Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon, CanCollide = false }, trackFolder)
	local finish = part({ Name = "FinishLine", Size = Vector3.new(2, 0.06, width), CFrame = CFrame.new(startX + RaceConfig.Length, center.Y + 0.04, center.Z), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false }, trackFolder)
	Portal.label(finish, "🏁 FINISH", Color3.new(1, 1, 1), 10)
	-- Grandstand along one side, with an exit portal
	part({ Name = "Grandstand", Size = Vector3.new(length, 1, 20), CFrame = CFrame.new(center.X, center.Y - 0.5, center.Z + width / 2 + 10), Color = Color3.fromRGB(70, 74, 90), Material = Enum.Material.DiamondPlate }, trackFolder)
	for i = 1, 3 do
		part({ Name = "Seats", Size = Vector3.new(length, 1.5 * i, 4), CFrame = CFrame.new(center.X, center.Y + 0.75 * i, center.Z + width / 2 + 10 + i * 4), Color = Color3.fromRGB(200, 40, 60), Material = Enum.Material.SmoothPlastic }, trackFolder)
	end
	-- Walls so nobody falls off
	for _, z in ipairs({ center.Z - width / 2 - 0.5, center.Z + width / 2 + 20.5 }) do
		part({ Name = "Wall", Size = Vector3.new(length, 4, 1), CFrame = CFrame.new(center.X, center.Y + 2, z), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Glass, Transparency = 0.5 }, trackFolder)
	end
	for _, x in ipairs({ center.X - length / 2 - 0.5, center.X + length / 2 + 0.5 }) do
		part({ Name = "Wall", Size = Vector3.new(1, 4, width + 21), CFrame = CFrame.new(x, center.Y + 2, center.Z + 10), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Glass, Transparency = 0.5 }, trackFolder)
	end

	local spectate = CFrame.new(center.X, center.Y + 4, center.Z + width / 2 + 8)
	Portal.create("RaceExit", Vector3.new(center.X - length / 2 + 10, center.Y, center.Z + width / 2 + 10), Color3.fromRGB(0, 170, 255), "🏠 BACK TO LOBBY", trackFolder, function(player)
		Portal.teleport(player, CFrame.new(RaceConfig.LobbyPortal + Vector3.new(0, 4, 8)))
	end, false)
	Portal.create("RacePortal", RaceConfig.LobbyPortal, Color3.fromRGB(255, 200, 40), "🏁 ROBOT RACES", workspace:FindFirstChild("Scenery") or workspace, function(player)
		Portal.teleport(player, spectate)
	end)
end

local function buildRacer(name, color, lane)
	local model = Instance.new("Model")
	model.Name = "Racer_" .. name
	local y = RaceConfig.Center.Y
	local base = CFrame.new(startX - 3, y, laneZ[lane]) * CFrame.Angles(0, -math.pi / 2, 0) -- faces +X
	local function piece(pname, size, offset, pcolor, material)
		local p = part({ Name = pname, Size = size, CFrame = base * offset, Color = pcolor, Material = material or Enum.Material.Metal, CanCollide = false }, model)
		return p
	end
	local body = piece("Body", Vector3.new(3, 2, 4), CFrame.new(0, 2, 0), color)
	model.PrimaryPart = body
	piece("Head", Vector3.new(2, 1.4, 1.6), CFrame.new(0, 3.7, -0.6), Color3.fromRGB(200, 205, 215))
	piece("Eyes", Vector3.new(1.6, 0.35, 0.1), CFrame.new(0, 3.8, -1.45), Color3.fromRGB(0, 255, 255), Enum.Material.Neon)
	piece("Wheels", Vector3.new(3.4, 1, 1), CFrame.new(0, 0.6, -1.4), Color3.fromRGB(20, 20, 24))
	piece("Wheels", Vector3.new(3.4, 1, 1), CFrame.new(0, 0.6, 1.4), Color3.fromRGB(20, 20, 24))
	piece("Booster", Vector3.new(1.2, 1.2, 0.6), CFrame.new(0, 2, 2.3), Color3.fromRGB(255, 140, 20), Enum.Material.Neon)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 24)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.MaxDistance = 300
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = name
	label.Parent = tag
	tag.Parent = body
	model.Parent = trackFolder
	return model
end

local function speedFor(level)
	return RaceConfig.BaseSpeed + (level - 1) * RaceConfig.SpeedPerLevel
end

local function runRace()
	workspace:SetAttribute("RaceState", "Racing")
	local racers = {}
	local lane = 0
	for _, player in ipairs(entrants) do
		local data = player.Parent and DataService:GetData(player)
		if data and lane < RaceConfig.Lanes then
			lane += 1
			table.insert(racers, { Player = player, Name = player.DisplayName, Level = data.RaceBotLevel, Lane = lane, Color = Color3.fromRGB(0, 220, 255) })
		end
	end
	table.clear(entrants)
	workspace:SetAttribute("RaceEntrants", "")
	-- AI fillers (always at least 4 racers)
	local aiIndex = 0
	while lane < math.min(RaceConfig.Lanes, math.max(4, #racers + 2)) do
		lane += 1
		aiIndex += 1
		local level = math.random(1, 8)
		table.insert(racers, { Name = AI_NAMES[(aiIndex - 1) % #AI_NAMES + 1] .. " (AI)", Level = level, Lane = lane, Color = AI_COLORS[(aiIndex - 1) % #AI_COLORS + 1] })
	end

	for _, racer in ipairs(racers) do
		racer.Model = buildRacer(racer.Name, racer.Color, racer.Lane)
		racer.Distance = 0
		racer.Speed = speedFor(racer.Level)
	end
	Net:NotifyAll("🏁 Robot race starting!", "info")

	local finishOrder = {}
	local wobbleTimer = 0
	local done = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		wobbleTimer += dt
		if wobbleTimer >= 1 then
			wobbleTimer = 0
			for _, racer in ipairs(racers) do
				racer.Speed = speedFor(racer.Level) + (math.random() * 2 - 1) * RaceConfig.RandomSpeed
			end
		end
		for _, racer in ipairs(racers) do
			if not racer.Finished then
				racer.Distance += racer.Speed * dt
				if racer.Distance >= RaceConfig.Length then
					racer.Distance = RaceConfig.Length
					racer.Finished = true
					table.insert(finishOrder, racer)
				end
				local y = RaceConfig.Center.Y + math.abs(math.sin(racer.Distance * 0.3)) * 0.3
				racer.Model:PivotTo(CFrame.new(startX - 3 + racer.Distance, y, laneZ[racer.Lane]) * CFrame.Angles(0, -math.pi / 2, 0))
			end
		end
		if #finishOrder == #racers then
			connection:Disconnect()
			done = true
		end
	end)
	local timeout = os.clock() + 60
	while not done and os.clock() < timeout do
		task.wait(0.25)
	end
	if not done then
		connection:Disconnect()
	end

	-- Results
	local podium = {}
	for place, racer in ipairs(finishOrder) do
		table.insert(podium, ("%d. %s"):format(place, racer.Name))
		local player = racer.Player
		local data = player and player.Parent and DataService:GetData(player)
		if data then
			local prize = RaceConfig.Prizes[place]
			if place == 1 then
				data.RaceWins += 1
			end
			if prize then
				prize *= RebirthConfig.GetMultiplier(data.Rebirths)
				EconomyService:AddCash(player, prize)
				Net:Notify(player, ("🏁 You finished #%d! +%s"):format(place, Format.cash(prize)), "success")
				Net:Fire(player, "Sfx", if place == 1 then "Rebirth" else "Cash")
				if place == 1 then
					Net:Fire(player, "Fx", "Confetti")
				end
			else
				Net:Notify(player, ("🏁 You finished #%d. Upgrade your race bot to go faster!"):format(place), "info")
			end
		end
	end
	if #podium > 0 then
		Net:NotifyAll("🏁 Race results: " .. table.concat(podium, "  ", 1, math.min(3, #podium)), "info")
	end
	task.wait(3)
	for _, racer in ipairs(racers) do
		racer.Model:Destroy()
	end
end

local function raceAction(player, action)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if action == "Join" then
		if table.find(entrants, player) then
			return
		end
		if #entrants >= RaceConfig.Lanes then
			Net:Notify(player, "The next race is full. Try the one after!", "error")
			return
		end
		table.insert(entrants, player)
		local names = {}
		for _, p in ipairs(entrants) do
			table.insert(names, p.DisplayName)
		end
		workspace:SetAttribute("RaceEntrants", table.concat(names, ", "))
		Net:Notify(player, "🏁 You're in the next race! Watch from the Robot Races portal in the lobby.", "success")
	elseif action == "Upgrade" then
		if data.RaceBotLevel >= RaceConfig.MaxLevel then
			return
		end
		local cost = RaceConfig.UpgradeCost(data.RaceBotLevel)
		if data.Robots < cost then
			Net:Notify(player, ("Upgrading needs %d robots."):format(cost), "error")
			return
		end
		EconomyService:AddStat(player, "Robots", -cost)
		data.RaceBotLevel += 1
		player:SetAttribute("RaceBotLevel", data.RaceBotLevel)
		Net:Fire(player, "Sfx", "Purchase")
	end
end

function RaceService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	Net = services.Net
end

function RaceService:Start()
	buildTrack()
	Net:On("RaceAction", raceAction, 2, 4)
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			local data = DataService:GetData(player)
			if data then
				player:SetAttribute("RaceBotLevel", data.RaceBotLevel)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(entrants, player)
		if index then
			table.remove(entrants, index)
		end
	end)
	task.spawn(function()
		while true do
			workspace:SetAttribute("RaceState", "Waiting")
			workspace:SetAttribute("RaceStartsAt", workspace:GetServerTimeNow() + RaceConfig.EntryWindow)
			task.wait(RaceConfig.EntryWindow)
			if #entrants > 0 then
				runRace()
			end
		end
	end)
end

return RaceService
