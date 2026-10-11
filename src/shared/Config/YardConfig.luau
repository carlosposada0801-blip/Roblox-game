--[[
	YardConfig
	Logistics Yard: a grid behind every factory where you build your own
	conveyor network. The Yard Dropper spits out crates (Common / Rare /
	Epic); route them to the sellers with pieces you place and rotate.
	  Conveyor        moves crates forward (takes crates from behind or the sides)
	  Speed Conveyor  twice as fast
	  Splitter        sends crates left, right, left, right... (takes them from behind)
	  Sorter          Rare and Epic crates go straight, Common ones turn right
	  Merger          takes crates from 3 sides and pushes them forward fast
	The Standard Seller pays normal value. The Rare Buyer pays RareBuyerBonus x
	for Rare/Epic crates but only CommonPenalty x for Common ones, so sorting pays!
	Throughput: the dropper is faster than one normal conveyor, so speed belts
	or splitting into two lines earns more.

	Grid: cell (0, 0) is the corner nearest the factory's left side; x runs
	along the back of the factory, y runs away from it. Rotation 0 = +x,
	1 = +y, 2 = -x, 3 = -y.
]]

local YardConfig = {}

YardConfig.Width = 24 -- cells along the back of the plot
YardConfig.Depth = 9 -- cells away from the plot
YardConfig.CellSize = 4
YardConfig.Gap = 6 -- studs between the plot's back edge and the yard

YardConfig.MaxCrates = 40 -- per yard (lag control)
YardConfig.MaxPieces = 120 -- per yard (each piece is a few parts)
YardConfig.DropInterval = 0.35 -- seconds between crates (when there's room)
YardConfig.TickRate = 10 -- simulation steps per second
YardConfig.CrateLifetime = 120 -- a crate stuck this long is removed

-- Reserved cells (can't build there)
YardConfig.Dropper = { X = 0, Y = 4, Rot = 0 } -- crates come out of the side it faces
YardConfig.Sellers = {
	{ Id = "Standard", Name = "Standard Seller", X = 23, Y = 2, Color = Color3.fromRGB(80, 230, 110) },
	{ Id = "RareBuyer", Name = "Rare Buyer", X = 23, Y = 6, Color = Color3.fromRGB(190, 90, 255) },
}
YardConfig.RareBuyerBonus = 3
YardConfig.CommonPenalty = 0.25

YardConfig.Rarities = {
	{ Id = "Common", Chance = 0.75, Value = 10, Color = Color3.fromRGB(170, 120, 70) },
	{ Id = "Rare", Chance = 0.2, Value = 30, Color = Color3.fromRGB(0, 170, 255) },
	{ Id = "Epic", Chance = 0.05, Value = 120, Color = Color3.fromRGB(190, 90, 255) },
}

-- CellTime = seconds for a crate to cross one cell
YardConfig.Pieces = {
	Conveyor = { Name = "Conveyor", Icon = "➡️", Price = 250, CellTime = 0.7, Order = 1, Color = Color3.fromRGB(255, 200, 40) },
	SpeedConveyor = { Name = "Speed Conveyor", Icon = "⏩", Price = 2500, CellTime = 0.35, Order = 2, Color = Color3.fromRGB(0, 220, 255) },
	Splitter = { Name = "Splitter", Icon = "🔀", Price = 5000, CellTime = 0.5, Order = 3, Color = Color3.fromRGB(255, 120, 40) },
	Sorter = { Name = "Sorter", Icon = "🎯", Price = 15000, CellTime = 0.5, Order = 4, Color = Color3.fromRGB(190, 90, 255) },
	Merger = { Name = "Merger", Icon = "⏬", Price = 5000, CellTime = 0.35, Order = 5, Color = Color3.fromRGB(80, 230, 110) },
}

-- Grid direction vectors for rotations 0..3
YardConfig.Directions = { [0] = Vector2.new(1, 0), [1] = Vector2.new(0, 1), [2] = Vector2.new(-1, 0), [3] = Vector2.new(0, -1) }

-- Plot-local CFrame of the yard floor's center
function YardConfig.FloorOffset(plotDepth: number): CFrame
	local cell = YardConfig.CellSize
	local depth = YardConfig.Depth * cell
	return CFrame.new(0, 0, -(plotDepth / 2 + YardConfig.Gap + depth / 2))
end

-- Position of a cell's center relative to the yard floor's center (floor top = y 0)
function YardConfig.CellOffset(x: number, y: number): Vector3
	local cell = YardConfig.CellSize
	return Vector3.new((x - (YardConfig.Width - 1) / 2) * cell, 0, ((YardConfig.Depth - 1) / 2 - y) * cell)
end

-- The cell under a point given in the yard floor's local space
function YardConfig.CellFromOffset(offset: Vector3): (number, number)
	local cell = YardConfig.CellSize
	local x = math.floor(offset.X / cell + (YardConfig.Width - 1) / 2 + 0.5)
	local y = math.floor((YardConfig.Depth - 1) / 2 - offset.Z / cell + 0.5)
	return x, y
end

function YardConfig.IsReserved(x: number, y: number): boolean
	if x == YardConfig.Dropper.X and y == YardConfig.Dropper.Y then
		return true
	end
	for _, seller in ipairs(YardConfig.Sellers) do
		if seller.X == x and seller.Y == y then
			return true
		end
	end
	return false
end

function YardConfig.InBounds(x: number, y: number): boolean
	return x >= 0 and y >= 0 and x < YardConfig.Width and y < YardConfig.Depth
end

return YardConfig
