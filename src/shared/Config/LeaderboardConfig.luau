--[[
	LeaderboardConfig
	Global leaderboards shown on boards in the lobby (OrderedDataStores).
	Stat is a key in the player's save data. Position is the board's world
	position; Facing is the direction its screen faces.

	Weekly = true: the board uses a fresh store every week (Monday 00:00 UTC)
	and ranks cash earned that week. When a week ends, the top WeeklyPrizes
	players get their prize the next time they join.
]]

return {
	Size = 10,
	Refresh = 60,
	-- Weekly board prizes by rank (title + robot skin), delivered on next join
	WeeklyPrizes = {
		{ Title = "🥇 Weekly Champion", Skin = "SkinChampion" },
		{ Title = "🥈 Weekly Runner-up", Skin = "SkinChampion" },
		{ Title = "🥉 Weekly Top 3", Skin = "SkinChampion" },
	},
	WeeklyLookback = 4, -- also check this many past weeks, for players who missed a week
	Boards = {
		{ Id = "Rebirths", Title = "🏆 TOP REBIRTHS", Stat = "Rebirths", Store = "RebirthLeaderboard_v1", Position = Vector3.new(0, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Richest", Title = "💰 RICHEST", Stat = "TotalEarned", Store = "CashLeaderboard_v1", Position = Vector3.new(-40, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Robots", Title = "🤖 MOST ROBOTS", Stat = "RobotsBuilt", Store = "RobotLeaderboard_v1", Position = Vector3.new(40, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Arena", Title = "⚔️ ARENA CHAMPIONS", Stat = "ArenaWins", Store = "ArenaLeaderboard_v1", Position = Vector3.new(-40, 9, -24), Facing = Vector3.new(0, 0, 1) },
		{ Id = "Weekly", Title = "📅 TOP EARNERS THIS WEEK", Weekly = true, Store = "WeeklyCash_v1", Position = Vector3.new(-80, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Liked", Title = "👍 MOST LIKED FACTORY", Stat = "Likes", Store = "LikesLeaderboard_v1", Position = Vector3.new(80, 9, 24), Facing = Vector3.new(0, 0, -1) },
		{ Id = "Battles", Title = "🥊 ROBOT BATTLE KINGS", Stat = "BattleWins", Store = "BattleLeaderboard_v1", Position = Vector3.new(-80, 9, -24), Facing = Vector3.new(0, 0, 1) },
		-- Custom: scores are set by CrewService (key = crew name, value = crew level)
		{ Id = "Crews", Title = "🛡️ TOP CREWS", Custom = true, Store = "CrewLeaderboard_v1", Position = Vector3.new(40, 9, -24), Facing = Vector3.new(0, 0, 1), Prefix = "Lv " },
	},
}
