--[[
	WeaponConfig
	Weapons are unlocked with cash in the Armory (saved forever) and show up
	in your backpack whenever you can fight:
	  * inside the PvP arena, or
	  * anywhere, when you AND the other player both have PvP switched on.

	Type
	  Melee   swing hits players in front of you within Range
	  Ranged  instant laser shot toward where you click (server checks range and line of sight)
	  Rocket  a slow rocket that explodes and hurts everyone within Radius
	RequiresPrototype weapons are free for anyone who owns a Prototype robot.
]]

return {
	PvPCombatLock = 10, -- seconds after a hit before you can switch PvP off

	Weapons = {
		{
			Id = "RoboSword",
			DisplayName = "Robo Sword",
			Icon = "🗡️",
			Description = "Fast neon blade. Everyone starts with one.",
			Type = "Melee",
			Price = 0,
			Damage = 20,
			Range = 8,
			Cooldown = 0.6,
			Color = Color3.fromRGB(0, 220, 255),
		},
		{
			Id = "LaserBlaster",
			DisplayName = "Laser Blaster",
			Icon = "🔫",
			Description = "Rapid-fire laser pistol.",
			Type = "Ranged",
			Price = 25000,
			Damage = 14,
			Range = 120,
			Cooldown = 0.4,
			Color = Color3.fromRGB(255, 60, 60),
		},
		{
			Id = "PlasmaHammer",
			DisplayName = "Plasma Hammer",
			Icon = "🔨",
			Description = "Slow, heavy smash that hits hard.",
			Type = "Melee",
			Price = 150000,
			Damage = 45,
			Range = 10,
			Cooldown = 1.2,
			Color = Color3.fromRGB(170, 80, 255),
		},
		{
			Id = "ShockRifle",
			DisplayName = "Shock Rifle",
			Icon = "⚡",
			Description = "Long-range lightning rifle.",
			Type = "Ranged",
			Price = 750000,
			Damage = 34,
			Range = 220,
			Cooldown = 0.9,
			Color = Color3.fromRGB(255, 230, 60),
		},
		{
			Id = "RocketLauncher",
			DisplayName = "Rocket Launcher",
			Icon = "🚀",
			Description = "Explosive rockets that hit everyone nearby.",
			Type = "Rocket",
			Price = 3000000,
			Damage = 60,
			Radius = 12,
			Range = 300,
			Speed = 90,
			Cooldown = 2.5,
			Color = Color3.fromRGB(255, 140, 20),
		},
		{
			Id = "PrototypeCannon",
			DisplayName = "Prototype Cannon",
			Icon = "⭐",
			Description = "Free for Prototype owners. Big glowing blasts.",
			Type = "Ranged",
			Price = 0,
			RequiresPrototype = true,
			Damage = 50,
			Range = 180,
			Cooldown = 1.5,
			Color = Color3.fromRGB(255, 80, 220),
		},
	},
}
