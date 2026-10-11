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

local function buildBorder(model, plotCFrame, color)
	local size = PlotConfig.PlotSize
	local border = Instance.new("Folder")
	border.Name = "Border"
	border.Parent = model

	local thickness, height = 1, 0.4
	local edges = {
		{ CFrame.new(0, height / 2, -size.Z / 2 + thickness / 2), Vector3.new(size.X, height, thickness) },
		{ CFrame.new(0, height / 2, size.Z / 2 - thickness / 2), Vector3.new(size.X, height, thickness) },
		{ CFrame.new(-size.X / 2 + thickness / 2, height / 2, 0), Vector3.new(thickness, height, size.Z) },
		{ CFrame.new(size.X / 2 - thickness / 2, height / 2, 0), Vector3.new(thickness, height, size.Z) },
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
end

local function buildGate(model, plotCFrame, color)
	local size = PlotConfig.PlotSize
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = model

	local frontZ = size.Z / 2 - 3
	local postHeight = 14
	for _, x in ipairs({ -14, 14 }) do
		makePart({
			Name = "Post",
			CFrame = plotCFrame * CFrame.new(x, postHeight / 2, frontZ),
			Size = Vector3.new(1.5, postHeight, 1.5),
			Color = Color3.fromRGB(40, 40, 45),
			Material = Enum.Material.Metal,
			Parent = gate,
		})
	end

	-- Rotate 180 degrees so the board's Front face points out toward the aisle (+Z).
	local board = makePart({
		Name = "Board",
		CFrame = plotCFrame * CFrame.new(0, postHeight + 2, frontZ) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(30, 5, 1),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = gate,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = PlotConfig.UnclaimedText
	label.Parent = surface

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
		SpawnCFrame = spawnCFrame,
		AccentColor = color,
		OwnerLabel = ownerLabel,
		Owner = nil,
	}
end

local function ensureGroundAndLobby()
	-- Works in both the Baseplate template and a completely empty place.
	if not workspace:FindFirstChild("Baseplate") and not workspace:FindFirstChild("FactoryGround") then
		makePart({
			Name = "FactoryGround",
			Size = Vector3.new(1024, 4, 1024),
			CFrame = CFrame.new(PlotConfig.Origin - Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(90, 140, 80),
			Material = Enum.Material.Grass,
			Parent = workspace,
		})
	end

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "LobbySpawn"
		spawnLocation.Anchored = true
		spawnLocation.Size = Vector3.new(12, 1, 12)
		spawnLocation.CFrame = CFrame.new(PlotConfig.Origin + Vector3.new(0, 0.5, 0))
		spawnLocation.Parent = workspace
	end
end

function PlotService:Init()
	ensureGroundAndLobby()

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

	for _, folderName in ipairs({ "Items", "Buttons", "Drops", "Workers" }) do
		plot.Model[folderName]:ClearAllChildren()
	end

	self.PlotReleased:Fire(player, plot)
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
