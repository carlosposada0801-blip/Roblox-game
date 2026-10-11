--[[
	SocialService
	  * Visit: teleport to any plot (VisitPlot remote, from the Players menu).
	  * Like: a "👍 Like" prompt on every gate (hidden on your own). One like
	    per factory per day. Likes are saved (data.Likes) and shown on the gate.
	  * Crown: the factory with the most likes in the server wears a crown.
]]

local DataService, PlotService, PlayerService, Net

local SocialService = {}

local crown

local function today()
	return os.time() // 86400
end

local function updateGate(plot)
	local likes = 0
	if plot.Owner then
		local data = DataService:GetData(plot.Owner)
		likes = data and data.Likes or 0
	end
	plot.Model:SetAttribute("Likes", likes)
	if plot.Owner then
		plot.Owner:SetAttribute("Likes", likes)
	end
	local label = plot.Model:FindFirstChild("LikesLabel", true)
	if label then
		label.Text = if plot.Owner then ("👍 %d"):format(likes) else ""
	end
end

local function updateCrown()
	local best, bestLikes = nil, 0
	for _, plot in ipairs(PlotService:GetPlots()) do
		local likes = plot.Model:GetAttribute("Likes") or 0
		if plot.Owner and likes > bestLikes then
			best, bestLikes = plot, likes
		end
	end
	if not best then
		crown.Parent = nil
		return
	end
	local gate = best.Model:FindFirstChild("Gate")
	local board = gate and gate:FindFirstChild("Board")
	if board then
		crown:PivotTo(board.CFrame * CFrame.new(0, 6.5, 0))
		crown.Parent = workspace
	end
end

local function buildCrown()
	local model = Instance.new("Model")
	model.Name = "TopFactoryCrown"
	local gold = Color3.fromRGB(255, 200, 40)
	local base = Instance.new("Part")
	base.Name = "Band"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(6, 1.2, 6)
	base.Color = gold
	base.Material = Enum.Material.Foil
	base.Parent = model
	model.PrimaryPart = base
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		local spike = Instance.new("Part")
		spike.Anchored = true
		spike.CanCollide = false
		spike.Size = Vector3.new(1, 2.2, 1)
		spike.CFrame = CFrame.new(math.cos(angle) * 2.4, 1.6, math.sin(angle) * 2.4)
		spike.Color = gold
		spike.Material = Enum.Material.Foil
		spike.Parent = model
		local gem = Instance.new("Part")
		gem.Anchored = true
		gem.CanCollide = false
		gem.Shape = Enum.PartType.Ball
		gem.Size = Vector3.new(0.9, 0.9, 0.9)
		gem.CFrame = CFrame.new(math.cos(angle) * 2.4, 2.9, math.sin(angle) * 2.4)
		gem.Color = Color3.fromRGB(255, 60, 120)
		gem.Material = Enum.Material.Neon
		gem.Parent = model
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 16
	light.Brightness = 2
	light.Parent = base
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = gold
	sparkles.Parent = base
	model:SetAttribute("Spin", 1)
	return model
end

local function attachLikePrompt(plot)
	local gate = plot.Model:FindFirstChild("Gate")
	local board = gate and gate:FindFirstChild("Board")
	if not board then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ActionText = "👍 Like this factory"
	prompt.ObjectText = "Factory"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 30
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("NotOwner", true)
	prompt.Parent = board

	prompt.Triggered:Connect(function(liker)
		local owner = plot.Owner
		if not owner or owner == liker then
			return
		end
		local likerData = DataService:GetData(liker)
		local ownerData = DataService:GetData(owner)
		if not (likerData and ownerData) then
			return
		end
		if likerData.LikesGiven.Day ~= today() then
			likerData.LikesGiven = { Day = today(), Ids = {} }
		end
		local key = tostring(owner.UserId)
		if likerData.LikesGiven.Ids[key] then
			Net:Notify(liker, "You already liked this factory today.", "info")
			return
		end
		likerData.LikesGiven.Ids[key] = true
		ownerData.Likes += 1
		updateGate(plot)
		updateCrown()
		Net:Notify(liker, "You liked " .. owner.DisplayName .. "'s factory! 👍", "success")
		Net:Notify(owner, liker.DisplayName .. " liked your factory! 👍", "special")
		Net:Fire(liker, "Sfx", "Purchase")
	end)
end

local function visit(player, plotId)
	if type(plotId) ~= "number" then
		return
	end
	local plot = PlotService:GetPlots()[plotId]
	if not plot or player:GetAttribute("InArena") then
		return
	end
	local character = player.Character
	if character then
		pcall(player.RequestStreamAroundAsync, player, plot.SpawnCFrame.Position, 5)
		character:PivotTo(plot.SpawnCFrame * CFrame.new(0, 0, 6))
	end
	if plot.Owner and plot.Owner ~= player then
		Net:Notify(player, ("Visiting %s's factory. Press F at the gate to like it!"):format(plot.Owner.DisplayName), "info")
	end
end

function SocialService:Init(services)
	DataService = services.DataService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	Net = services.Net
end

function SocialService:Start()
	crown = buildCrown()
	for _, plot in ipairs(PlotService:GetPlots()) do
		attachLikePrompt(plot)
		updateGate(plot)
	end

	PlayerService.PlayerReady:Connect(function(_, _, plot)
		updateGate(plot)
		updateCrown()
	end)
	PlotService.PlotReleased:Connect(function(_, plot)
		updateGate(plot)
		updateCrown()
	end)

	Net:On("VisitPlot", visit, 1, 2)
end

return SocialService
