--[[
	BossConfig
	Raid boss: a giant evil robot lands in the lobby every Interval seconds,
	after a server-wide announcement and a countdown (Warning seconds).
	Health scales with the number of players. Everyone gets their weapons
	while it's alive (or can just click/tap it); damage is tracked per
	player on the server and the loot is split by damage dealt.
]]

return {
	FirstDelay = 600, -- first boss 10 minutes after the server starts
	Interval = 3600, -- then every hour
	Warning = 60, -- countdown before it lands
	Duration = 180, -- leaves if not defeated in time
	HealthPerPlayer = 1500,
	MinHealth = 2000,
	Position = Vector3.new(120, 0, 0), -- lobby aisle (world)
	Attack = { Every = 4, Damage = 25, Radius = 10, WarningTime = 1.2, Range = 90 },
	-- Cash x rebirth multiplier, split by damage share (min 25%). Rare robots:
	-- a Prototype at PrototypeChance. The exclusive Omega Destroyer robot skin
	-- drops at SkinChance (higher for the top damage dealer).
	Reward = { Cash = 100000, Robots = 10, PrototypeChance = 0.15, Skin = "SkinOmega", SkinChance = 0.04, TopDamageSkinChance = 0.12 },
	ClickDamage = 15, -- tapping/clicking the boss also hurts it (good for mobile)
}
