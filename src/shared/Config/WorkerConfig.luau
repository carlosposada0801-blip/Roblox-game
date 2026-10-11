--[[
	WorkerConfig
	Robots that reach your collector are added to your robot count. Spend them
	to hire worker bots that permanently boost your factory.

	Three kinds of worker:
	  Speed workers      DropperSpeed  { Amount = 0.1 }   +10% dropper speed per bot
	  Value workers      MachineValue  { Machine = "Smelter", Amount = 0.25 } +25% value
	                     from that machine per bot (Machine = "*" boosts every machine)
	  Collector workers  AutoCollect   { Amount = 0.2 }   every CollectEvery seconds, moves
	                     20% of the cash waiting on your pad into your cash, per bot

	Slots are plot-local positions where hired bots live (Max = number of slots).
	Hired bots walk between their slot and the machine they help (WorkAt item id).
	SlotRebirths: slot N of every worker type unlocks at SlotRebirths[N] rebirths.
]]

local WorkerConfig = {}

WorkerConfig.SlotRebirths = { 0, 0, 1, 2, 3 } -- rebirths needed for the 1st, 2nd, 3rd... bot of each type
WorkerConfig.CollectEvery = 5 -- seconds between Collector Bot pickups

WorkerConfig.Workers = {
	{
		Id = "SpeedyBot",
		DisplayName = "Speedy Bot",
		Description = "Droppers work 10% faster",
		Icon = "⚡",
		Cost = 3, -- robots
		Effect = { Type = "DropperSpeed", Amount = 0.1 },
		WorkAt = "Dropper1",
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
		WorkAt = "Smelter",
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
		WorkAt = "Assembler",
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
		WorkAt = "Painter",
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
		WorkAt = "FinalAssembly",
		Color = Color3.fromRGB(85, 255, 127),
		Slots = { Vector3.new(34, 0, -36), Vector3.new(40, 0, -36) },
	},
	{
		Id = "CollectorBot",
		DisplayName = "Collector Bot",
		Description = "Grabs 20% of your pad cash every 5s",
		Icon = "🧲",
		Cost = 5,
		Effect = { Type = "AutoCollect", Amount = 0.2 },
		WorkAt = "Collector",
		Color = Color3.fromRGB(120, 255, 200),
		Slots = { Vector3.new(36, 0, 31), Vector3.new(40, 0, 31), Vector3.new(44, 0, 31) },
	},
}

-- How many bots of this type the player may hire at this many rebirths
function WorkerConfig.GetMaxSlots(worker, rebirths: number): number
	local max = 0
	for index = 1, #worker.Slots do
		if rebirths >= (WorkerConfig.SlotRebirths[index] or 0) then
			max = index
		end
	end
	return max
end

return WorkerConfig
