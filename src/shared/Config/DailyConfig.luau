--[[
	DailyConfig
	Daily login rewards. Claim once per UTC day. Logging in on consecutive
	days builds a streak; missing a full day resets it to day 1.
	Days 1-6 give cash (growing each day); day 7 gives a guaranteed rare
	Prototype robot plus cash. Then the 7 days repeat.
	Cash rewards are multiplied by the player's rebirth multiplier.
]]

return {
	CashScalesWithRebirths = true,
	Rewards = {
		{ Cash = 1000 },
		{ Cash = 2500 },
		{ Cash = 5000 },
		{ Cash = 10000 },
		{ Cash = 20000 },
		{ Cash = 40000 },
		{ Cash = 50000, Prototypes = 1 }, -- day 7 jackpot: a guaranteed rare Prototype robot
	},
}
