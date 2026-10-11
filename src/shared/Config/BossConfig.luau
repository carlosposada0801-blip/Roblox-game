--[[
	BossConfig
	Raid boss: a giant evil robot lands in the lobby every Interval seconds.
	Everyone gets their weapons while it's alive; anyone who damaged it
	shares the reward when it's destroyed.
]]

return {
	FirstDelay = 300,
	Interval = 900, -- 15 minutes
	Duration = 180, -- leaves if not defeated in time
	HealthPerPlayer = 1500,
	MinHealth = 2000,
	Position = Vector3.new(120, 0, 0), -- lobby aisle (world)
	Attack = { Every = 4, Damage = 25, Radius = 10, WarningTime = 1.2, Range = 90 },
	Reward = { Cash = 100000, Robots = 10, PrototypeChance = 0.15 }, -- cash x rebirth multiplier, split by damage share (min 25%)
	ClickDamage = 15, -- tapping/clicking the boss also hurts it (good for mobile)
}
