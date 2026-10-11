--[[
	ArenaConfig
	The shared PvP arena. It floats above the map. Step on the portal in the
	lobby to enter. Everyone gets a Robo Sword; Prototype owners can deploy
	their Prototype robot, which follows them and zaps nearby enemies.
]]

local ArenaConfig = {}

ArenaConfig.Center = Vector3.new(0, 400, 0) -- floor surface center
ArenaConfig.Size = Vector3.new(140, 2, 140)
ArenaConfig.WallHeight = 14
ArenaConfig.LobbyPortal = Vector3.new(24, 0, 0) -- world position of the entry portal

ArenaConfig.SpawnProtection = 3 -- seconds of force field after entering

ArenaConfig.Sword = {
	Damage = 20,
	Range = 8,
	Cooldown = 0.6,
}

ArenaConfig.Prototype = {
	Damage = 12, -- per zap
	Range = 40,
	Cooldown = 2.5,
	ExtraPrototypeBonus = 0.1, -- +10% damage per extra Prototype owned
	MaxBonus = 1, -- capped at +100%
	FollowOffset = Vector3.new(4, 3, 2),
}

ArenaConfig.KillReward = 500 -- cash, multiplied by the killer's rebirth multiplier
ArenaConfig.KillCreditTime = 10 -- seconds a hit counts toward a kill

return ArenaConfig
