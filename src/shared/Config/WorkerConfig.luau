--[[
	WorkerConfig
	Robots that reach your collector are added to your robot count. Spend them
	to hire worker bots that permanently boost your factory.

	Effect types
	  DropperSpeed  { Amount = 0.1 }                     +10% dropper speed per bot
	  MachineValue  { Machine = "Smelter", Amount = 0.25 } +25% value from that machine per bot
	                Machine = "*" boosts every machine

	Slots are plot-local positions where hired bots stand (Max = number of slots).
]]

local WorkerConfig = {}

WorkerConfig.Workers = {
	{
		Id = "SpeedyBot",
		DisplayName = "Speedy Bot",
		Description = "Droppers work 10% faster",
		Icon = "⚡",
		Cost = 3, -- robots
		Effect = { Type = "DropperSpeed", Amount = 0.1 },
		Color = Color3.fromRGB(255, 220, 60),
		Slots = {
			Vector3.new(-44, 0, -36),
			Vector3.new(-38, 0, -36),
			Vector3.new(-32, 0, -36),
			Vector3.new(-26, 0, -36),
			Vector3.new(-20, 0, -36),
		},
	},
	{
		Id = "FurnaceBot",
		DisplayName = "Furnace Bot",
		Description = "Smelter adds 25% more value",
		Icon = "🔥",
		Cost = 4,
		Effect = { Type = "MachineValue", Machine = "Smelter", Amount = 0.25 },
		Color = Color3.fromRGB(255, 110, 40),
		Slots = { Vector3.new(-14, 0, -31), Vector3.new(-10, 0, -31), Vector3.new(-6, 0, -31) },
	},
	{
		Id = "WelderBot",
		DisplayName = "Welder Bot",
		Description = "Assembler adds 25% more value",
		Icon = "🔧",
		Cost = 6,
		Effect = { Type = "MachineValue", Machine = "Assembler", Amount = 0.25 },
		Color = Color3.fromRGB(0, 170, 255),
		Slots = { Vector3.new(2, 0, -31), Vector3.new(6, 0, -31), Vector3.new(10, 0, -31) },
	},
	{
		Id = "ArtistBot",
		DisplayName = "Artist Bot",
		Description = "Painter adds 25% more value",
		Icon = "🎨",
		Cost = 8,
		Effect = { Type = "MachineValue", Machine = "Painter", Amount = 0.25 },
		Color = Color3.fromRGB(255, 80, 200),
		Slots = { Vector3.new(16, 0, -31), Vector3.new(20, 0, -31), Vector3.new(24, 0, -31) },
	},
	{
		Id = "ForemanBot",
		DisplayName = "Foreman Bot",
		Description = "Every machine adds 15% more value",
		Icon = "👷",
		Cost = 15,
		Effect = { Type = "MachineValue", Machine = "*", Amount = 0.15 },
		Color = Color3.fromRGB(85, 255, 127),
		Slots = { Vector3.new(34, 0, -36), Vector3.new(40, 0, -36) },
	},
}

return WorkerConfig
