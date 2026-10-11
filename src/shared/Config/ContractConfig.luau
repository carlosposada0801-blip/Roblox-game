--[[
	ContractConfig
	Timed jobs. Pick one of 3 offers; finish it before the timer runs out
	for a big reward (x rebirth multiplier). Uses the same stats as quests.
]]

return {
	Cooldown = 60, -- seconds between contracts
	Offers = {
		{ Id = "RareRun", Text = "Sell %d Rare-or-better robots", Stat = "RareRobots", Goal = 5, Time = 600, Reward = { Cash = 60000, Robots = 5 } },
		{ Id = "PaintJob", Text = "Paint %d items", Stat = "ItemsPainted", Goal = 150, Time = 480, Reward = { Cash = 40000 } },
		{ Id = "RushOrder", Text = "Sell %d robots", Stat = "RobotsSold", Goal = 40, Time = 600, Reward = { Cash = 50000, Robots = 3 } },
		{ Id = "CashGrab", Text = "Earn $%s", Stat = "CashEarned", Goal = 200000, Time = 420, Reward = { Cash = 80000 } },
		{ Id = "PadDuty", Text = "Collect from your cash pad %d times", Stat = "PadCollects", Goal = 30, Time = 300, Reward = { Cash = 25000 } },
		{ Id = "DroneSweep", Text = "Destroy %d rogue drones", Stat = "DronesDestroyed", Goal = 3, Time = 900, Reward = { Cash = 70000 } },
	},
}
