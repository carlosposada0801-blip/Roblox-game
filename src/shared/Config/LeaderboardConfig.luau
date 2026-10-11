--[[
	LeaderboardConfig
	Global leaderboards shown on boards in the lobby (OrderedDataStores).
	Stat is a key in the player's save data. Position is the board's world
	position; Facing is the direction its screen faces.
]]

return {
	Size = 10,
	Refresh = 60,
	Boards = {
		{ Id = "Rebirths", Title = "🏆 TOP REBIRTHS", Stat = "Rebirths", Store = "RebirthLeaderboard_v1", Position = Vector3.new(0, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Richest", Title = "💰 RICHEST", Stat = "TotalEarned", Store = "CashLeaderboard_v1", Position = Vector3.new(-40, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Robots", Title = "🤖 MOST ROBOTS", Stat = "RobotsBuilt", Store = "RobotLeaderboard_v1", Position = Vector3.new(40, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Arena", Title = "⚔️ ARENA CHAMPIONS", Stat = "ArenaWins", Store = "ArenaLeaderboard_v1", Position = Vector3.new(-40, 9, -24), Facing = Vector3.new(0, 0, 1) },
		-- Custom: scores are set by CrewService (key = crew name, value = crew level)
		{ Id = "Crews", Title = "🛡️ TOP CREWS", Custom = true, Store = "CrewLeaderboard_v1", Position = Vector3.new(40, 9, -24), Facing = Vector3.new(0, 0, 1), Prefix = "Lv " },
	},
}
