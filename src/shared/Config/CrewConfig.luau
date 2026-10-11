--[[
	CrewConfig
	Crews (clans) work across servers. Create one, others join by name.
	Members donate cash to the crew bank; the owner spends it on crew
	levels, which give every member a cash bonus.
]]

return {
	StoreName = "Crews_v1",
	LeaderboardStore = "CrewLeaderboard_v1",
	CreateCost = 50000,
	MaxMembers = 20,
	MaxLevel = 10,
	BonusPerLevel = 0.05, -- +5% cash per crew level
	LevelCost = function(level)
		return math.floor(250000 * 2.2 ^ (level - 1))
	end,
	NamePattern = "^[%w ]+$", -- letters, numbers and spaces
	NameLength = { 3, 16 },
}
