--[[
	YardService
	Logistics Yard (YardConfig): a building grid behind each factory.
	  * YardAction("Place", x, y, pieceType, rotation): buys a piece and puts it
	    on the grid. Placing the same type on its own cell just rotates it (free).
	  * YardAction("Remove", x, y): removes a piece and refunds its price.
	  The server checks everything: the cell is inside the yard grid, isn't a
	  reserved cell (dropper/sellers), the piece type and rotation are valid,
	  and the player can afford it. Saved as data.Yard["x,y"] = { T, R }.

	Crates are simulated on the server on the grid (not physics): each crate
	sits in one cell, moves cell to cell at its piece's speed, and waits if
	the next cell is busy or has nothing to carry it. Crates are anchored,
	non-colliding parts moved with BulkMoveTo, capped per yard.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local YardConfig = require(Shared.Config.YardConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlotService, PlayerService, QuestService, Net

local YardService = {}

local yards = {} -- [Player] = yard
--[[
	yard = {
		Player, Plot, Model, Floor (Part), Pieces = { [key] = { T, R, Model, Toggle } },
		Crates = { crate }, Occupied = { [key] = crate }, DropTimer,
	}
	crate = { Part, X, Y, FromPos, Progress, Out (rotation), Rarity, Age }
]]

local function key(x, y)
	return x .. "," .. y
end

local function cellCFrame(yard, x, y)
	return yard.Floor.CFrame * CFrame.new(YardConfig.CellOffset(x, y) + Vector3.new(0, yard.Floor.Size.Y / 2, 0))
end

local function rotationCFrame(rotation)
	return CFrame.Angles(0, rotation * math.pi / 2, 0)
end

-- Building -------------------------------------------------------------------------------

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function chevron(model, base, color, offset, angle)
	local at = base * CFrame.new(offset) * CFrame.Angles(0, angle or 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Arrow",
			Size = Vector3.new(1.4, 0.05, 0.35),
			CFrame = at * CFrame.new(-0.35, 0, side * 0.45) * CFrame.Angles(0, side * math.rad(40), 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, model)
	end
end

local function buildPiece(yard, x, y, pieceType, rotation)
	local config = YardConfig.Pieces[pieceType]
	local size = YardConfig.CellSize
	local base = cellCFrame(yard, x, y) * rotationCFrame(rotation)
	local model = Instance.new("Model")
	model.Name = pieceType
	model:SetAttribute("Cell", key(x, y))
	part({ Name = "Belt", Size = Vector3.new(size - 0.2, 0.4, size - 0.6), CFrame = base * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.DiamondPlate, CanCollide = false }, model)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Rail", Size = Vector3.new(size - 0.2, 0.5, 0.25), CFrame = base * CFrame.new(0, 0.45, side * (size / 2 - 0.3)), Color = config.Color, Material = Enum.Material.Metal, CanCollide = false }, model)
	end
	local top = base * CFrame.new(0, 0.43, 0)
	if pieceType == "Splitter" then
		chevron(model, top, config.Color, Vector3.new(0, 0, 0), math.rad(90))
		chevron(model, top, config.Color, Vector3.new(0, 0, 0), math.rad(-90))
	elseif pieceType == "Sorter" then
		chevron(model, top, Color3.fromRGB(0, 170, 255), Vector3.new(0.8, 0, 0))
		chevron(model, top, Color3.fromRGB(170, 120, 70), Vector3.new(0, 0, 0), math.rad(-90))
	elseif pieceType == "Merger" then
		chevron(model, top, config.Color, Vector3.new(0.9, 0, 0))
		chevron(model, top, config.Color, Vector3.new(-0.5, 0, 0))
	else
		chevron(model, top, config.Color, Vector3.new(0.6, 0, 0))
		if pieceType == "SpeedConveyor" then
			chevron(model, top, config.Color, Vector3.new(-0.4, 0, 0))
		end
	end
	model.Parent = yard.Model.Pieces
	return model
end

local function buildYard(player, plot)
	local model = Instance.new("Model")
	model.Name = "Yard"
	local width, depth, size = YardConfig.Width, YardConfig.Depth, YardConfig.CellSize
	local floorCFrame = plot.CFrame * YardConfig.FloorOffset(plot.Model.Base.Size.Z) * CFrame.new(0, -0.5, 0)
	local floor = part({
		Name = "YardFloor",
		Size = Vector3.new(width * size, 1, depth * size),
		CFrame = floorCFrame,
		Color = Color3.fromRGB(52, 56, 66),
		Material = Enum.Material.Concrete,
	}, model)
	floor:SetAttribute("OwnerId", player.UserId)
	-- Grid lines
	for gx = 0, width do
		part({ Name = "GridLine", Size = Vector3.new(0.12, 0.05, depth * size), CFrame = floorCFrame * CFrame.new((gx - width / 2) * size, 0.52, 0), Color = Color3.fromRGB(90, 100, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 0.6 }, model)
	end
	for gy = 0, depth do
		part({ Name = "GridLine", Size = Vector3.new(width * size, 0.05, 0.12), CFrame = floorCFrame * CFrame.new(0, 0.52, (gy - depth / 2) * size), Color = Color3.fromRGB(90, 100, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 0.6 }, model)
	end

	local yard = { Player = player, Plot = plot, Model = model, Floor = floor, Pieces = {}, Crates = {}, Occupied = {}, DropTimer = 0 }

	-- Sign
	local signPart = part({ Name = "YardSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CFrame = floorCFrame * CFrame.new(0, 10, 0) }, model)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 60)
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 40)
	label.TextStrokeTransparency = 0.2
	label.Text = "📦 LOGISTICS YARD\nBuild conveyors in the Yard menu!"
	label.Parent = gui
	gui.Parent = signPart

	-- Dropper
	local dropper = YardConfig.Dropper
	local dropBase = cellCFrame(yard, dropper.X, dropper.Y) * rotationCFrame(dropper.Rot)
	part({ Name = "YardDropper", Size = Vector3.new(3.6, 5, 3.6), CFrame = dropBase * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Metal }, model)
	part({ Name = "DropperLight", Size = Vector3.new(3.8, 0.5, 3.8), CFrame = dropBase * CFrame.new(0, 4.2, 0), Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Neon, CanCollide = false }, model)
	chevron(model, dropBase * CFrame.new(1.9, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 220, 60), Vector3.new())

	-- Sellers
	for _, seller in ipairs(YardConfig.Sellers) do
		local base = cellCFrame(yard, seller.X, seller.Y)
		local box = part({ Name = "Seller_" .. seller.Id, Size = Vector3.new(3.8, 4, 3.8), CFrame = base * CFrame.new(0, 2, 0), Color = Color3.fromRGB(40, 42, 55), Material = Enum.Material.Metal }, model)
		part({ Name = "SellerGlow", Size = Vector3.new(4, 0.6, 4), CFrame = base * CFrame.new(0, 4.2, 0), Color = seller.Color, Material = Enum.Material.Neon, CanCollide = false }, model)
		local sellerGui = Instance.new("BillboardGui")
		sellerGui.Size = UDim2.fromOffset(150, 40)
		sellerGui.StudsOffset = Vector3.new(0, 4, 0)
		sellerGui.MaxDistance = 80
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Sarpanch
		text.TextScaled = true
		text.TextColor3 = seller.Color
		text.TextStrokeTransparency = 0.2
		text.Text = if seller.Id == "RareBuyer" then ("💎 RARE BUYER\nx%d Rare/Epic"):format(YardConfig.RareBuyerBonus) else "💵 SELLER"
		text.Parent = sellerGui
		sellerGui.Parent = box
	end

	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = model
	local crates = Instance.new("Folder")
	crates.Name = "Crates"
	crates.Parent = model

	model.Parent = plot.Model
	return yard
end

-- Simulation -------------------------------------------------------------------------------

local function sellerAt(x, y)
	for _, seller in ipairs(YardConfig.Sellers) do
		if seller.X == x and seller.Y == y then
			return seller
		end
	end
	return nil
end

-- Which way a crate leaves a piece it entered moving in direction `entering`.
-- Returns nil if the piece doesn't accept crates from that side.
local function outputFor(piece, entering, crate)
	local r = piece.R
	local back = entering == r -- crate is moving the same way the piece points
	local front = entering == (r + 2) % 4
	if piece.T == "Conveyor" or piece.T == "SpeedConveyor" or piece.T == "Merger" then
		if front then
			return nil
		end
		return r
	elseif piece.T == "Splitter" then
		if not back then
			return nil
		end
		piece.Toggle = not piece.Toggle
		return if piece.Toggle then (r + 1) % 4 else (r + 3) % 4
	elseif piece.T == "Sorter" then
		if not back then
			return nil
		end
		return if crate.Rarity.Id == "Common" then (r + 3) % 4 else r
	end
	return nil
end

local function rollRarity()
	local roll = math.random()
	for _, rarity in ipairs(YardConfig.Rarities) do
		roll -= rarity.Chance
		if roll <= 0 then
			return rarity
		end
	end
	return YardConfig.Rarities[1]
end

local function removeCrate(yard, index)
	local crate = yard.Crates[index]
	yard.Occupied[key(crate.X, crate.Y)] = nil
	crate.Part:Destroy()
	table.remove(yard.Crates, index)
end

local function sell(yard, crate, seller)
	local value = crate.Rarity.Value
	if seller.Id == "RareBuyer" then
		value *= if crate.Rarity.Id == "Common" then YardConfig.CommonPenalty else YardConfig.RareBuyerBonus
	end
	EconomyService:Earn(yard.Player, value)
	QuestService:Track(yard.Player, "YardSales", 1)
end

local function spawnCrate(yard)
	local dropper = YardConfig.Dropper
	local dir = YardConfig.Directions[dropper.Rot]
	local x, y = dropper.X + dir.X, dropper.Y + dir.Y
	local piece = yard.Pieces[key(x, y)]
	if not piece or yard.Occupied[key(x, y)] or #yard.Crates >= YardConfig.MaxCrates then
		return
	end
	local crate = { X = x, Y = y, Progress = 0, Rarity = rollRarity(), Age = 0 }
	local out = outputFor(piece, dropper.Rot, crate)
	if not out then
		return
	end
	crate.Out = out
	local startCFrame = cellCFrame(yard, dropper.X, dropper.Y) * CFrame.new(0, 1.2, 0)
	crate.FromPos = startCFrame.Position
	crate.Part = part({
		Name = "Crate",
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = startCFrame,
		Color = crate.Rarity.Color,
		Material = if crate.Rarity.Id == "Common" then Enum.Material.WoodPlanks else Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, yard.Model.Crates)
	yard.Occupied[key(x, y)] = crate
	table.insert(yard.Crates, crate)
end

local movedParts, movedCFrames = {}, {}

local function stepYard(yard, dt)
	yard.DropTimer += dt
	if yard.DropTimer >= YardConfig.DropInterval then
		yard.DropTimer = 0
		spawnCrate(yard)
	end

	for index = #yard.Crates, 1, -1 do
		local crate = yard.Crates[index]
		crate.Age += dt
		local piece = yard.Pieces[key(crate.X, crate.Y)]
		if not piece or not crate.Part.Parent or crate.Age > YardConfig.CrateLifetime then
			removeCrate(yard, index)
			continue
		end
		local target = cellCFrame(yard, crate.X, crate.Y) * CFrame.new(0, 1.2, 0)
		if crate.Progress < 1 then
			crate.Progress = math.min(1, crate.Progress + dt / YardConfig.Pieces[piece.T].CellTime)
			table.insert(movedParts, crate.Part)
			table.insert(movedCFrames, CFrame.new(crate.FromPos:Lerp(target.Position, crate.Progress)) * target.Rotation)
		else
			-- At the cell center: try to move on
			local dir = YardConfig.Directions[crate.Out]
			local nx, ny = crate.X + dir.X, crate.Y + dir.Y
			local seller = sellerAt(nx, ny)
			if seller then
				sell(yard, crate, seller)
				removeCrate(yard, index)
			else
				local moved = false
				if YardConfig.InBounds(nx, ny) and not yard.Occupied[key(nx, ny)] then
					local nextPiece = yard.Pieces[key(nx, ny)]
					local out = nextPiece and outputFor(nextPiece, crate.Out, crate)
					if out then
						yard.Occupied[key(crate.X, crate.Y)] = nil
						crate.FromPos = target.Position
						crate.X, crate.Y, crate.Out, crate.Progress = nx, ny, out, 0
						yard.Occupied[key(nx, ny)] = crate
						moved = true
					end
				end
				-- A splitter whose chosen side is blocked tries the other side
				if not moved and piece.T == "Splitter" then
					crate.Out = (crate.Out + 2) % 4
				end
			end
		end
	end
end

-- Placing --------------------------------------------------------------------------------

local function sync(player)
	local data = DataService:GetData(player)
	if data then
		local count = 0
		for _ in pairs(data.Yard) do
			count += 1
		end
		player:SetAttribute("YardPieces", count)
	end
end

local function placePiece(yard, x, y, pieceType, rotation)
	local k = key(x, y)
	local old = yard.Pieces[k]
	if old and old.Model then
		old.Model:Destroy()
	end
	local piece = { T = pieceType, R = rotation, Toggle = false }
	piece.Model = buildPiece(yard, x, y, pieceType, rotation)
	yard.Pieces[k] = piece
end

local function isInt(value, low, high)
	return type(value) == "number" and value == value and value == math.floor(value) and value >= low and value <= high
end

local function action(player, kind, x, y, pieceType, rotation)
	local data = DataService:GetData(player)
	local yard = yards[player]
	if not (data and yard) or type(kind) ~= "string" then
		return
	end
	if not (isInt(x, 0, YardConfig.Width - 1) and isInt(y, 0, YardConfig.Depth - 1)) then
		return -- outside the yard grid
	end
	local k = key(x, y)
	if kind == "Place" then
		local config = type(pieceType) == "string" and YardConfig.Pieces[pieceType]
		if not config or not isInt(rotation, 0, 3) or YardConfig.IsReserved(x, y) then
			return
		end
		local existing = data.Yard[k]
		if existing then
			if existing.T ~= pieceType then
				Net:Notify(player, "Something is already there. Remove it first.", "error")
				return
			end
			existing.R = rotation -- same piece: just rotate it (free)
		else
			if not EconomyService:TrySpend(player, config.Price) then
				Net:Notify(player, ("%s costs %s."):format(config.Name, Format.cash(config.Price)), "error")
				Net:Fire(player, "Sfx", "Denied")
				return
			end
			data.Yard[k] = { T = pieceType, R = rotation }
			Net:Fire(player, "Sfx", "Purchase")
		end
		placePiece(yard, x, y, pieceType, rotation)
	elseif kind == "Remove" then
		local existing = data.Yard[k]
		if not existing then
			return
		end
		data.Yard[k] = nil
		local piece = yard.Pieces[k]
		if piece then
			piece.Model:Destroy()
			yard.Pieces[k] = nil
		end
		local config = YardConfig.Pieces[existing.T]
		if config then
			EconomyService:AddCash(player, config.Price)
		end
		Net:Fire(player, "Sfx", "Click")
	end
	sync(player)
end

local function setup(player, _, plot)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local yard = buildYard(player, plot)
	yards[player] = yard
	-- Rebuild saved pieces (skipping anything invalid)
	for k, saved in pairs(data.Yard) do
		local x, y = string.match(k, "^(%d+),(%d+)$")
		x, y = tonumber(x), tonumber(y)
		if x and y and YardConfig.InBounds(x, y) and not YardConfig.IsReserved(x, y) and YardConfig.Pieces[saved.T] and isInt(saved.R, 0, 3) then
			placePiece(yard, x, y, saved.T, saved.R)
		else
			data.Yard[k] = nil
		end
	end
	sync(player)
end

local function teardown(player)
	local yard = yards[player]
	if yard then
		yards[player] = nil
		yard.Model:Destroy()
	end
end

function YardService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	Net = services.Net
end

function YardService:Start()
	PlayerService.PlayerReady:Connect(setup)
	PlotService.PlotReleased:Connect(teardown)
	Players.PlayerRemoving:Connect(teardown)
	Net:On("YardAction", action, 8, 12)

	local interval = 1 / YardConfig.TickRate
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < interval then
			return
		end
		local step = math.min(elapsed, 0.5)
		elapsed = 0
		for _, yard in pairs(yards) do
			stepYard(yard, step)
		end
		if #movedParts > 0 then
			workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(movedParts)
			table.clear(movedCFrames)
		end
	end)
end

-- For tests
function YardService:GetCrateCount(player: Player): number
	local yard = yards[player]
	return yard and #yard.Crates or 0
end

return YardService
