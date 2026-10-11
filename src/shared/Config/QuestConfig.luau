--[[
	QuestConfig
	Every day (UTC) each player gets QuestsPerDay quests picked from Pool.
	Progress only comes from the server: other services call
	QuestService:Track(player, stat, amount) when something happens.
	Goals: one of the listed numbers is picked at random.
	Reward: Cash (x rebirth multiplier), Robots, Prototypes, or a short
	Boost = { Id = <BoostConfig id>, Minutes = n }.
]]

return {
	QuestsPerDay = 3,
	Pool = {
		{ Id = "BuildRobots", Text = "Build %d robots", Stat = "RobotsSold", Goals = { 10, 25, 50 }, Reward = { Robots = 4, Boost = { Id = "Turbo", Minutes = 5 } } },
		{ Id = "EarnCash", Text = "Earn $%s", Stat = "CashEarned", Goals = { 5000, 25000, 100000 }, Reward = { Cash = 5000 } },
		{ Id = "BuyItems", Text = "Buy %d factory items", Stat = "ItemsBought", Goals = { 3, 6 }, Reward = { Cash = 3000 } },
		{ Id = "HireWorkers", Text = "Hire %d workers", Stat = "WorkersHired", Goals = { 1, 3 }, Reward = { Robots = 5 } },
		{ Id = "CollectPad", Text = "Collect cash %d times", Stat = "PadCollects", Goals = { 10, 20 }, Reward = { Boost = { Id = "CashX2", Minutes = 5 } } },
		{ Id = "ArenaKnockouts", Text = "Win %d arena fights", Stat = "ArenaKnockouts", Goals = { 1, 3 }, Reward = { Cash = 8000 } },
		{ Id = "BattleWins", Text = "Win %d robot battle", Stat = "BattleWins", Goals = { 1 }, Reward = { Boost = { Id = "CashX2", Minutes = 10 } } },
		{ Id = "Upgrades", Text = "Buy %d upgrades", Stat = "Upgrades", Goals = { 2, 5 }, Reward = { Cash = 6000 } },
		{ Id = "Hatch", Text = "Hatch %d pet eggs", Stat = "EggsHatched", Goals = { 1, 3 }, Reward = { Robots = 6 } },
		{ Id = "RareRobots", Text = "Build %d Rare-or-better robots", Stat = "RareRobots", Goals = { 1, 3 }, Reward = { Boost = { Id = "Lucky", Minutes = 5 } } },
		{ Id = "Paint", Text = "Paint %d items", Stat = "ItemsPainted", Goals = { 20, 60 }, Reward = { Cash = 4000 } },
		{ Id = "YardSales", Text = "Sell %d crates in your Logistics Yard", Stat = "YardSales", Goals = { 25, 75 }, Reward = { Boost = { Id = "Turbo", Minutes = 10 } } },
	},
}
