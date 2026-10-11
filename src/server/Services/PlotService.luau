--[[
	PlotService
	Builds the tycoon plots from PlotConfig and assigns one to each player.

	Each plot is a Model in workspace.Plots:
	  Plot3 (Model)  attributes: PlotId, OwnerId
	    Base         the floor (PrimaryPart)
	    Border       accent-colored trim
	    Gate         entrance sign showing the owner's name
	    Spawn        invisible marker where the owner appears
	    Items        unlocked tycoon items        (step 2+)
	    Buttons      buy buttons                  (step 2+)
	    Drops        moving scrap / robot parts   (step 3+)
	    Workers      hired worker bots            (step 6+)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared.Config.PlotConfig)
local SkyConfig = require(Shared.Config.SkyConfig)
local Signal = require(Shared.Util.Signal)

local PlotService = {}
PlotService.PlotClaimed = Signal.new() -- (player, plot)
PlotService.PlotReleased = Signal.new() -- (player, plot)

local plots = {} -- array of plot records
local plotByPlayer = {} -- [Player] = plot record

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- Plots alternate sides of a central aisle so every entrance faces the aisle.
local function computePlotCFrame(index)
	local size = PlotConfig.PlotSize
	local columns = PlotConfig.Columns
	local row = (index - 1) // columns
	local column = (index - 1) % columns

	local rowWidth = columns * size.X + (columns - 1) * PlotConfig.PlotGap
	local x = -rowWidth / 2 + size.X / 2 + column * (size.X + PlotConfig.PlotGap)
	local distanceFromAisle = PlotConfig.AisleWidth / 2 + size.Z / 2 + (row // 2) * (size.Z + PlotConfig.PlotGap)
	local y = PlotConfig.Origin.Y + size.Y

	local origin = PlotConfig.Origin
	if row % 2 == 0 then
		return CFrame.new(origin.X + x, y, origin.Z - distanceFromAisle)
	else
		return CFrame.new(origin.X + x, y, origin.Z + distanceFromAisle) * CFrame.Angles(0, math.pi, 0)
	end
end

-- Yellow/black hazard stripes around the edge, glowing corner pylons, and a faint floor grid
local function buildBorder(model, plotCFrame, color)
	local size = PlotConfig.PlotSize
	local border = Instance.new("Folder")
	border.Name = "Border"
	border.Parent = model

	local stripeLength, height, width = 4, 0.3, 1.2
	local yellow, black = Color3.fromRGB(255, 200, 40), Color3.fromRGB(25, 25, 28)
	local halfX, halfZ = size.X / 2 - width / 2, size.Z / 2 - width / 2

	-- Long edges (along X) and short edges (along Z)
	local index = 0
	for x = -size.X / 2 + stripeLength / 2, size.X / 2 - stripeLength / 2, stripeLength do
		index += 1
		for _, z in ipairs({ -halfZ, halfZ }) do
			makePart({
				Name = "Stripe",
				CFrame = plotCFrame * CFrame.new(x, height / 2, z),
				Size = Vector3.new(stripeLength, height, width),
				Color = if index % 2 == 0 then yellow else black,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = border,
			})
		end
	end
	index = 0
	for z = -size.Z / 2 + stripeLength / 2 + width, size.Z / 2 - stripeLength / 2 - width, stripeLength do
		index += 1
		for _, x in ipairs({ -halfX, halfX }) do
			makePart({
				Name = "Stripe",
				CFrame = plotCFrame * CFrame.new(x, height / 2, z),
				Size = Vector3.new(width, height, stripeLength),
				Color = if index % 2 == 0 then yellow else black,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = border,
			})
		end
	end

	-- Inner neon outline in the plot's color
	local inset = width + 0.4
	local edges = {
		{ CFrame.new(0, 0.05, -size.Z / 2 + inset), Vector3.new(size.X - inset * 2, 0.1, 0.4) },
		{ CFrame.new(0, 0.05, size.Z / 2 - inset), Vector3.new(size.X - inset * 2, 0.1, 0.4) },
		{ CFrame.new(-size.X / 2 + inset, 0.05, 0), Vector3.new(0.4, 0.1, size.Z - inset * 2) },
		{ CFrame.new(size.X / 2 - inset, 0.05, 0), Vector3.new(0.4, 0.1, size.Z - inset * 2) },
	}
	for i, edge in ipairs(edges) do
		makePart({
			Name = "Edge" .. i,
			CFrame = plotCFrame * edge[1],
			Size = edge[2],
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = border,
		})
	end

	-- Corner pylons with a glowing cap
	for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = corner[1] * (size.X / 2 - 1), corner[2] * (size.Z / 2 - 1)
		makePart({ Name = "Pylon", CFrame = plotCFrame * CFrame.new(x, 2, z), Size = Vector3.new(2, 4, 2), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.DiamondPlate, Parent = border })
		local cap = makePart({ Name = "PylonCap", CFrame = plotCFrame * CFrame.new(x, 4.3, z), Size = Vector3.new(2.2, 0.6, 2.2), Color = color, Material = Enum.Material.Neon, Parent = border })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = cap
	end

	-- Faint glowing floor grid
	for offset = -size.X / 2 + 20, size.X / 2 - 20, 20 do
		makePart({ Name = "Grid", CFrame = plotCFrame * CFrame.new(offset, 0.02, 0), Size = Vector3.new(0.2, 0.05, size.Z - 6), Color = color, Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false, CanQuery = false, Parent = border })
		makePart({ Name = "Grid", CFrame = plotCFrame * CFrame.new(0, 0.02, offset), Size = Vector3.new(size.X - 6, 0.05, 0.2), Color = color, Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false, CanQuery = false, Parent = border })
	end
end

local function makeLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	for key, value in pairs(props) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- Industrial gate: hazard pillars, a big sign with the owner's name, spinning gears and warning lights
local function buildGate(model, plotCFrame, color)
	local size = PlotConfig.PlotSize
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = model

	local frontZ = size.Z / 2 - 3
	local postHeight = 16
	for _, x in ipairs({ -16, 16 }) do
		makePart({ Name = "Post", CFrame = plotCFrame * CFrame.new(x, postHeight / 2, frontZ), Size = Vector3.new(3, postHeight, 3), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.DiamondPlate, Parent = gate })
		for band = 1, 3 do
			makePart({ Name = "PostStripe", CFrame = plotCFrame * CFrame.new(x, band * 4 - 1, frontZ), Size = Vector3.new(3.1, 1, 3.1), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.SmoothPlastic, Parent = gate })
		end
		local lamp = makePart({ Name = "WarningLight", Shape = Enum.PartType.Ball, CFrame = plotCFrame * CFrame.new(x, postHeight + 0.8, frontZ), Size = Vector3.new(1.6, 1.6, 1.6), Color = Color3.fromRGB(255, 80, 40), Material = Enum.Material.Neon, Parent = gate })
		lamp:SetAttribute("Blink", true)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 80, 40)
		light.Range = 14
		light.Parent = lamp
		-- Spinning gear on each post
		makePart({ Name = "Gear", CFrame = plotCFrame * CFrame.new(x, postHeight - 3, frontZ + 1.7) * CFrame.Angles(math.rad(90), 0, 0), Size = Vector3.new(4.5, 0.4, 0.9), Color = color, Material = Enum.Material.Neon, Parent = gate }):SetAttribute("Spin", 2)
		makePart({ Name = "Gear", CFrame = plotCFrame * CFrame.new(x, postHeight - 3, frontZ + 1.7) * CFrame.Angles(math.rad(90), 0, 0), Size = Vector3.new(0.9, 0.4, 4.5), Color = color, Material = Enum.Material.Neon, Parent = gate }):SetAttribute("Spin", 2)
	end

	-- Rotate 180 degrees so the board's Front face points out toward the aisle (+Z).
	local board = makePart({
		Name = "Board",
		CFrame = plotCFrame * CFrame.new(0, postHeight + 1, frontZ) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(34, 7, 1.2),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.SmoothPlastic,
		Parent = gate,
	})
	makePart({ Name = "BoardTrim", CFrame = board.CFrame * CFrame.new(0, -3.7, 0), Size = Vector3.new(34.4, 0.5, 1.4), Color = color, Material = Enum.Material.Neon, Parent = gate })
	makePart({ Name = "BoardTrim", CFrame = board.CFrame * CFrame.new(0, 3.7, 0), Size = Vector3.new(34.4, 0.5, 1.4), Color = color, Material = Enum.Material.Neon, Parent = gate })

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.LightInfluence = 0
	surface.Parent = board

	makeLabel(surface, { Name = "Title", Size = UDim2.fromScale(1, 0.32), Font = Enum.Font.Michroma, TextColor3 = color, Text = "ROBOT FACTORY" })
	local label = makeLabel(surface, { Name = "OwnerLabel", Position = UDim2.fromScale(0.03, 0.32), Size = UDim2.fromScale(0.94, 0.48), Font = Enum.Font.Sarpanch, Text = PlotConfig.UnclaimedText })
	makeLabel(surface, { Name = "LikesLabel", Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 220, 120), Text = "" })

	return label
end

local function buildPlot(index, parent)
	local plotCFrame = computePlotCFrame(index)
	local size = PlotConfig.PlotSize
	local color = PlotConfig.AccentColors[(index - 1) % #PlotConfig.AccentColors + 1]

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotId", index)
	model:SetAttribute("OwnerId", 0)

	local base = makePart({
		Name = "Base",
		CFrame = plotCFrame * CFrame.new(0, -size.Y / 2, 0),
		Size = size,
		Color = PlotConfig.BaseColor,
		Material = PlotConfig.BaseMaterial,
		Parent = model,
	})
	model.PrimaryPart = base

	buildBorder(model, plotCFrame, color)
	local ownerLabel = buildGate(model, plotCFrame, color)

	local spawnCFrame = plotCFrame * PlotConfig.SpawnOffset
	makePart({
		Name = "Spawn",
		CFrame = spawnCFrame,
		Size = Vector3.new(4, 1, 4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	for _, folderName in ipairs({ "Items", "Buttons", "Drops", "Workers" }) do
		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = model
	end

	model.Parent = parent

	return {
		Id = index,
		Model = model,
		CFrame = plotCFrame, -- plot local space; use plot.CFrame * offset to place things
		SkyCFrame = plotCFrame * CFrame.new(0, SkyConfig.Height, 0), -- Sky Factory island (SkyConfig)
		SpawnCFrame = spawnCFrame,
		AccentColor = color,
		OwnerLabel = ownerLabel,
		Owner = nil,
	}
end

-- The ground and scenery come from SceneryService. This only makes sure
-- there's a lobby spawn, and moves the template's spawn off the walkway.
local function ensureLobbySpawn()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "LobbySpawn"
		spawnLocation.Anchored = true
		spawnLocation.Size = Vector3.new(12, 1, 12)
		spawnLocation.Parent = workspace
	end
	spawnLocation.CFrame = CFrame.new(PlotConfig.LobbySpawn)
end

function PlotService:Init()
	ensureLobbySpawn()

	-- Plots are generated at runtime; remove any copy left in the place file.
	local existing = workspace:FindFirstChild("Plots")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace

	for index = 1, PlotConfig.PlotCount do
		plots[index] = buildPlot(index, folder)
	end
end

-- Returns the player's plot record, claiming the first free plot if needed.
-- Returns nil when every plot is taken.
function PlotService:ClaimPlot(player: Player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end

	for _, plot in ipairs(plots) do
		if plot.Owner == nil then
			plot.Owner = player
			plotByPlayer[player] = plot
			plot.Model:SetAttribute("OwnerId", player.UserId)
			plot.OwnerLabel.Text = PlotConfig.ClaimedTextFormat:format(player.DisplayName)
			player:SetAttribute("PlotId", plot.Id)
			self.PlotClaimed:Fire(player, plot)
			return plot
		end
	end

	return nil
end

function PlotService:ReleasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end

	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerId", 0)
	plot.OwnerLabel.Text = PlotConfig.UnclaimedText
	self:Restyle(plot, {})

	for _, folderName in ipairs({ "Items", "Buttons", "Drops", "Workers" }) do
		plot.Model[folderName]:ClearAllChildren()
	end

	self.PlotReleased:Fire(player, plot)
end

-- Recolors a plot's floor and neon (ascension themes and accent cosmetics).
-- style = { Base = Color3?, Material = Enum.Material?, Accent = Color3? }; nil values mean "plot default".
local ACCENT_PARTS = { Edge1 = true, Edge2 = true, Edge3 = true, Edge4 = true, PylonCap = true, Grid = true, BoardTrim = true, Gear = true }
function PlotService:Restyle(plot, style)
	local base = plot.Model:FindFirstChild("Base")
	if base then
		base.Color = style.Base or PlotConfig.BaseColor
		base.Material = style.Material or PlotConfig.BaseMaterial
	end
	local accent = style.Accent or plot.AccentColor
	for _, descendant in ipairs(plot.Model:GetDescendants()) do
		if descendant:IsA("BasePart") and ACCENT_PARTS[descendant.Name] then
			descendant.Color = accent
			local light = descendant:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = accent
			end
		elseif descendant:IsA("TextLabel") and descendant.Name == "Title" then
			descendant.TextColor3 = accent
		end
	end
end

function PlotService:GetPlot(player: Player)
	return plotByPlayer[player]
end

function PlotService:GetPlots()
	return plots
end

function PlotService:TeleportToPlot(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if not (plot and character) then
		return
	end

	-- With streaming enabled, load the area first so the player doesn't fall through
	pcall(player.RequestStreamAroundAsync, player, plot.SpawnCFrame.Position, 5)

	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	-- Let the default spawn finish placing the character first, or it can override our move.
	task.wait()
	if root and player.Character == character and plotByPlayer[player] == plot then
		character:PivotTo(plot.SpawnCFrame)
	end
end

return PlotService
