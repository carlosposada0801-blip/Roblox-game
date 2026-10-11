--[[
	DailyConfig
	Daily login rewards. Claim once per day (UTC). Logging in on consecutive
	days builds a streak; missing a day resets it. The 7 rewards repeat.
	Cash rewards are multiplied by the player's rebirth multiplier.
]]

return {
	CashScalesWithRebirths = true,
	Rewards = {
		{ Cash = 1000 },
		{ Cash = 2500 },
		{ Robots = 3 },
		{ Cash = 10000 },
		{ Robots = 8 },
		{ Cash = 40000 },
		{ Cash = 50000, Prototypes = 1 }, -- day 7 jackpot
	},
}
