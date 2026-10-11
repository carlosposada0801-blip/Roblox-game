--[[
	QuestConfig
	Every day each player gets QuestsPerDay quests picked from Pool.
	Stat names are tracked by QuestService:Track(player, stat, amount).
	Goals: one of the listed numbers is picked at random.
	Cash rewards are multiplied by the rebirth multiplier.
]]

return {
	QuestsPerDay = 3,
	Pool = {
		{ Id = "BuildRobots", Text = "Sell %d robots", Stat = "RobotsSold", Goals = { 10, 25, 50 }, Reward = { Robots = 4 } },
		{ Id = "EarnCash", Text = "Earn $%s", Stat = "CashEarned", Goals = { 5000, 25000, 100000 }, Reward = { Cash = 5000 } },
		{ Id = "BuyItems", Text = "Buy %d factory items", Stat = "ItemsBought", Goals = { 3, 6 }, Reward = { Cash = 3000 } },
		{ Id = "HireWorkers", Text = "Hire %d workers", Stat = "WorkersHired", Goals = { 1, 3 }, Reward = { Robots = 5 } },
		{ Id = "CollectPad", Text = "Collect from your cash pad %d times", Stat = "PadCollects", Goals = { 10, 25 }, Reward = { Cash = 2500 } },
		{ Id = "ArenaKnockouts", Text = "Win %d arena fights", Stat = "ArenaKnockouts", Goals = { 1, 3 }, Reward = { Cash = 8000 } },
		{ Id = "Upgrades", Text = "Upgrade machines %d times", Stat = "Upgrades", Goals = { 2, 5 }, Reward = { Cash = 6000 } },
		{ Id = "Hatch", Text = "Hatch %d pet eggs", Stat = "EggsHatched", Goals = { 1, 3 }, Reward = { Robots = 6 } },
		{ Id = "RareRobots", Text = "Build %d Rare-or-better robots", Stat = "RareRobots", Goals = { 1, 3 }, Reward = { Cash = 10000 } },
		{ Id = "Paint", Text = "Paint %d items", Stat = "ItemsPainted", Goals = { 20, 60 }, Reward = { Cash = 4000 } },
	},
}
