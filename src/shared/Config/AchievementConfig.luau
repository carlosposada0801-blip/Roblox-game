--[[
	AchievementConfig
	Achievements unlock automatically when Stat >= Goal (save data fields,
	or the special stats listed in AchievementService). Each can award a
	Roblox badge (BadgeId; create badges in the Creator Dashboard and paste
	the IDs; 0 = no badge) and unlock a chat/overhead Title.

	Badge checklist (create these first): FirstRobot, FirstRebirth, Rebirth10,
	Prototype, BossSlayer, SkyHigh, FirstTrade, Famous (100 likes).
]]

return {
	Achievements = {
		{ Id = "FirstRobot", Name = "First Robot", Description = "Sell your first robot", Stat = "RobotsBuilt", Goal = 1, BadgeId = 0, Title = "Rookie Builder" },
		{ Id = "Robots100", Name = "Assembly Line", Description = "Sell 100 robots", Stat = "RobotsBuilt", Goal = 100, BadgeId = 0, Title = "Robot Maker" },
		{ Id = "Robots1000", Name = "Robot Army", Description = "Sell 1,000 robots", Stat = "RobotsBuilt", Goal = 1000, BadgeId = 0, Title = "🤖 Robot Baron" },
		{ Id = "Millionaire", Name = "Millionaire", Description = "Earn $1M in total", Stat = "TotalEarned", Goal = 1000000, BadgeId = 0, Title = "💰 Millionaire" },
		{ Id = "Billionaire", Name = "Billionaire", Description = "Earn $1B in total", Stat = "TotalEarned", Goal = 1000000000, BadgeId = 0, Title = "💎 Billionaire" },
		{ Id = "FirstRebirth", Name = "Born Again", Description = "Rebirth once", Stat = "Rebirths", Goal = 1, BadgeId = 0, Title = "Reborn" },
		{ Id = "Rebirth10", Name = "Rebirth Master", Description = "Reach 10 rebirths", Stat = "Rebirths", Goal = 10, BadgeId = 0, Title = "🔄 Rebirth Master" },
		{ Id = "Ascended", Name = "Ascended", Description = "Ascend for the first time", Stat = "Ascensions", Goal = 1, BadgeId = 0, Title = "✨ Ascended" },
		{ Id = "Legendary", Name = "Legendary Pull", Description = "Sell a Legendary robot", Stat = "LegendaryRobots", Goal = 1, BadgeId = 0, Title = "🌟 Lucky" },
		{ Id = "Collector20", Name = "Collector", Description = "Find 20 robots for your book", Stat = "BookEntries", Goal = 20, BadgeId = 0, Title = "📖 Collector" },
		{ Id = "Collector40", Name = "Complete Book", Description = "Find all 40 robots", Stat = "BookEntries", Goal = 40, BadgeId = 0, Title = "📚 Archivist" },
		{ Id = "Prototype", Name = "Prototype!", Description = "Own a Prototype robot", Stat = "Prototypes", Goal = 1, BadgeId = 0, Title = "⭐ Inventor" },
		{ Id = "FirstKO", Name = "First Blood", Description = "Get a PvP knockout", Stat = "Kills", Goal = 1, BadgeId = 0, Title = "Brawler" },
		{ Id = "KO100", Name = "Warlord", Description = "Get 100 knockouts", Stat = "Kills", Goal = 100, BadgeId = 0, Title = "⚔️ Warlord" },
		{ Id = "ArenaChamp", Name = "Champion", Description = "Win an arena round", Stat = "ArenaWins", Goal = 1, BadgeId = 0, Title = "🏆 Champion" },
		{ Id = "BossSlayer", Name = "Boss Slayer", Description = "Help defeat a raid boss", Stat = "BossKills", Goal = 1, BadgeId = 0, Title = "🛡️ Boss Slayer" },
		{ Id = "DroneHunter", Name = "Drone Hunter", Description = "Destroy 25 rogue drones", Stat = "DroneKills", Goal = 25, BadgeId = 0, Title = "🎯 Drone Hunter" },
		{ Id = "RaceWinner", Name = "Speed Demon", Description = "Win a robot race", Stat = "RaceWins", Goal = 1, BadgeId = 0, Title = "🏁 Speed Demon" },
		{ Id = "Contractor", Name = "Contractor", Description = "Finish 10 contracts", Stat = "ContractsDone", Goal = 10, BadgeId = 0, Title = "📜 Contractor" },
		{ Id = "Miner", Name = "Deep Miner", Description = "Craft a Machine Core", Stat = "Cores", Goal = 1, BadgeId = 0, Title = "⛏️ Miner" },
		{ Id = "Mythic", Name = "Mythical", Description = "Own a Mythic pet", Stat = "MythicPets", Goal = 1, BadgeId = 0, Title = "🌌 Mythical" },
		{ Id = "Popular", Name = "Popular", Description = "Get 25 likes on your factory", Stat = "Likes", Goal = 25, BadgeId = 0, Title = "👍 Popular" },
		{ Id = "Famous", Name = "Famous Factory", Description = "Get 100 likes on your factory", Stat = "Likes", Goal = 100, BadgeId = 0, Title = "🌟 Famous" },
		{ Id = "SkyHigh", Name = "Sky High", Description = "Unlock the Sky Factory", Stat = "SkyUnlocked", Goal = 1, BadgeId = 0, Title = "☁️ Sky Boss" },
		{ Id = "FirstTrade", Name = "Deal Maker", Description = "Complete your first trade", Stat = "Trades", Goal = 1, BadgeId = 0, Title = "🤝 Trader" },
		{ Id = "BattleWinner", Name = "Bot Brawler", Description = "Win a robot battle", Stat = "BattleWins", Goal = 1, BadgeId = 0, Title = "🥊 Bot Brawler" },
	},
}
