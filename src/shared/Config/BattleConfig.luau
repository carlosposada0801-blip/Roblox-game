--[[
	BattleConfig
	Robot Battle Arena: players send their Prototype robots into a ring at
	the end of the lobby for 1v1, stat-based fights. Join the queue from the
	Battle window (or the terminal by the ring). When two players are
	queued they're matched; a lone player gets a Training Bot after
	PracticeWait seconds. Wins/losses are saved and ranked on the lobby board.

	Prototype stats: base stats grow with how many Prototypes you own and
	your rebirths (capped), so collecting Prototypes makes your fighter stronger.
]]

return {
	Ring = Vector3.new(-198, 0, 0), -- world position (end of the lobby aisle)
	RingRadius = 14,
	MinPrototypes = 1, -- you need a Prototype to fight

	TurnTime = 1.1, -- seconds between attacks
	MaxTurns = 40, -- after this, the robot with more health left wins
	CountdownSeconds = 3,
	PracticeWait = 20, -- seconds alone in the queue before a Training Bot shows up

	Stats = {
		Health = 100,
		Attack = 12,
		PerExtraPrototype = 0.08, -- +8% health and attack per extra Prototype owned
		PerRebirth = 0.02, -- +2% per rebirth
		MaxBonus = 1.5, -- capped at +150%
		CritChance = 0.15,
		CritMultiplier = 2,
		DodgeChance = 0.08,
	},

	TrainingBot = { Name = "Training Bot", Health = 90, Attack = 9 },

	Rewards = {
		WinCash = 15000, -- x rebirth multiplier
		LoseCash = 3000, -- consolation, x rebirth multiplier
		PracticeWinCash = 4000, -- vs the Training Bot (doesn't count as a ranked win)
	},
}
