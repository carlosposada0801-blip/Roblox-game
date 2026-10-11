--[[
	SkyService
	Sky Factory (SkyConfig): a floating island above each plot.
	  * Unlocks at SkyConfig.UnlockRebirths (data.SkyUnlocked = 1, a badge
	    achievement). Checked on join and after every rebirth.
	  * A teleport pad in the factory takes the owner (and co-op builders) up;
	    before unlocking it shows how many rebirths are needed.
	  * The island's items are normal tycoon items with World = "Sky"
	    (TycoonService builds them on plot.SkyCFrame and saves them in data.Sky).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkyConfig = require(Shared.Config.SkyConfig)

local DataService, PlotService, PlayerService, TycoonService, CoopService, Net

local SkyService = {}

local built = {} -- [Player] = { Island = Model?, Pad = Model }

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

local function sign(parent, text, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffset = Vector3.new(0, height or 4, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

local function isUnlocked(data)
	return data.SkyUnlocked == 1
end

local function teleport(player, cframe)
	local character = player.Character
	if not character or player:GetAttribute("InArena") then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, cframe.Position, 5)
	if player.Character == character then
		character:PivotTo(cframe)
	end
end

local function hookPad(pad, owner, destination)
	local last = {}
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local toucher = character and Players:GetPlayerFromCharacter(character)
		if not toucher or os.clock() - (last[toucher] or 0) < 2 then
			return
		end
		local data = DataService:GetData(owner)
		if not (data and CoopService:CanBuild(toucher, owner)) then
			return
		end
		last[toucher] = os.clock()
		if not isUnlocked(data) then
			Net:Notify(toucher, ("☁️ The Sky Factory unlocks at %d rebirths."):format(SkyConfig.UnlockRebirths), "info")
			return
		end
		task.spawn(teleport, toucher, destination())
	end)
end

local function buildIsland(plot)
	local model = Instance.new("Model")
	model.Name = "SkyIsland"
	local base = plot.SkyCFrame
	local size = SkyConfig.IslandSize
	local white = Color3.fromRGB(235, 240, 250)
	local blue = Color3.fromRGB(120, 200, 255)

	part({ Name = "IslandFloor", Size = Vector3.new(size.X, 1, size.Z), CFrame = base * CFrame.new(0, -0.5, 0), Color = white, Material = Enum.Material.SmoothPlastic }, model)
	part({ Name = "IslandBody", Size = Vector3.new(size.X - 4, size.Y, size.Z - 4), CFrame = base * CFrame.new(0, -1 - size.Y / 2, 0), Color = Color3.fromRGB(120, 105, 90), Material = Enum.Material.Slate }, model)
	-- Rocky underside
	local random = Random.new(plot.Id)
	for _ = 1, 14 do
		local radius = random:NextNumber(10, 22)
		part({
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(radius * 2, radius * 2, radius * 2),
			CFrame = base * CFrame.new(random:NextNumber(-40, 40), -size.Y - radius * 0.6, random:NextNumber(-40, 40)),
			Color = Color3.fromRGB(110, 95, 80),
			Material = Enum.Material.Rock,
			CanCollide = false,
		}, model)
	end
	-- Glowing rim and invisible safety walls
	for _, edge in ipairs({
		{ Vector3.new(0, 0, size.Z / 2), Vector3.new(size.X, 0.6, 0.8) },
		{ Vector3.new(0, 0, -size.Z / 2), Vector3.new(size.X, 0.6, 0.8) },
		{ Vector3.new(size.X / 2, 0, 0), Vector3.new(0.8, 0.6, size.Z) },
		{ Vector3.new(-size.X / 2, 0, 0), Vector3.new(0.8, 0.6, size.Z) },
	}) do
		part({ Name = "Rim", Size = edge[2], CFrame = base * CFrame.new(edge[1] + Vector3.new(0, 0.3, 0)), Color = blue, Material = Enum.Material.Neon }, model)
		part({ Name = "SafetyWall", Size = edge[2] + Vector3.new(0, 12, 0), CFrame = base * CFrame.new(edge[1] + Vector3.new(0, 6.5, 0)), Transparency = 1, CanQuery = false }, model)
	end
	-- Clouds
	for _ = 1, 10 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(70, 110)
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(random:NextNumber(14, 26), random:NextNumber(6, 10), random:NextNumber(14, 26)),
			CFrame = base * CFrame.new(math.cos(angle) * distance, random:NextNumber(-20, 10), math.sin(angle) * distance),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, model)
	end
	local title = part({ Name = "Title", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = base * CFrame.new(0, 26, 0) }, model)
	sign(title, "☁️ SKY FACTORY", blue, 0)

	-- Pad back down
	local returnPad = part({ Name = "ReturnPad", Size = Vector3.new(6, 0.5, 6), CFrame = base * CFrame.new(SkyConfig.ReturnPad + Vector3.new(0, 0.25, 0)), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon, CanCollide = false }, model)
	sign(returnPad, "⬇ BACK TO FACTORY", Color3.fromRGB(255, 220, 90))
	model.Parent = plot.Model
	return model, returnPad
end

local function buildGroundPad(plot, owner, data)
	local model = Instance.new("Model")
	model.Name = "SkyPad"
	local pad = part({
		Name = "SkyPad",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = plot.CFrame * CFrame.new(SkyConfig.GroundPad + Vector3.new(0, 0.25, 0)),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)
	part({ Name = "Beam", Size = Vector3.new(1, 18, 1), CFrame = pad.CFrame * CFrame.new(0, 9, 0), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, CanCollide = false, CanQuery = false }, model)
	local label = sign(pad, "", Color3.fromRGB(150, 220, 255), 5)
	label.Text = if isUnlocked(data) then "☁️ SKY FACTORY ⬆" else ("☁️ SKY FACTORY\n🔒 %d rebirths"):format(SkyConfig.UnlockRebirths)
	model.Parent = plot.Model
	hookPad(pad, owner, function()
		return plot.SkyCFrame * CFrame.new(SkyConfig.Spawn)
	end)
	return model, label
end

-- Builds the pad (and the island once unlocked). Safe to call again.
local function refresh(player)
	local data = DataService:GetData(player)
	local plot = PlotService:GetPlot(player)
	if not (data and plot) then
		return
	end
	local entry = built[player]
	if not entry or entry.Plot ~= plot then
		local padModel, label = buildGroundPad(plot, player, data)
		entry = { Plot = plot, Pad = padModel, Label = label }
		built[player] = entry
	end

	if not isUnlocked(data) and data.Rebirths >= SkyConfig.UnlockRebirths then
		data.SkyUnlocked = 1
		Net:Notify(player, "☁️ SKY FACTORY UNLOCKED! Step on the blue pad in your factory to fly up!", "special")
		Net:Fire(player, "Fx", "Confetti")
		Net:Fire(player, "Sfx", "Rebirth")
		TycoonService:RefreshButtons(player)
	end
	player:SetAttribute("SkyUnlocked", isUnlocked(data))
	if isUnlocked(data) then
		entry.Label.Text = "☁️ SKY FACTORY ⬆"
		if not entry.Island then
			local island, returnPad = buildIsland(plot)
			entry.Island = island
			hookPad(returnPad, player, function()
				return plot.SpawnCFrame
			end)
		end
	end
end

local function teardown(player)
	local entry = built[player]
	built[player] = nil
	if entry then
		entry.Pad:Destroy()
		if entry.Island then
			entry.Island:Destroy()
		end
	end
end

function SkyService:Init(services)
	DataService = services.DataService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	TycoonService = services.TycoonService
	CoopService = services.CoopService
	Net = services.Net
end

function SkyService:Start()
	PlayerService.PlayerReady:Connect(refresh)
	TycoonService.TycoonReset:Connect(function(player)
		refresh(player)
	end)
	PlotService.PlotReleased:Connect(teardown)
	Net:On("SkyAction", function(player, kind)
		if kind == "Go" then
			self:GoToSky(player)
		elseif kind == "Home" then
			PlotService:TeleportToPlot(player)
		end
	end, 0.5, 2)
end

-- Teleports the player to their island (Sky menu button)
function SkyService:GoToSky(player: Player)
	local data = DataService:GetData(player)
	local plot = PlotService:GetPlot(player)
	if data and plot and isUnlocked(data) then
		task.spawn(teleport, player, plot.SkyCFrame * CFrame.new(SkyConfig.Spawn))
	end
end

-- Studio testing
function SkyService:DevUnlock(player: Player)
	local data = DataService:GetData(player)
	if data then
		data.Rebirths = math.max(data.Rebirths, SkyConfig.UnlockRebirths)
		refresh(player)
		self:GoToSky(player)
	end
end

return SkyService
