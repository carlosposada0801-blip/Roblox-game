--[[
	MiningConfig
	A floating crystal mine (portal in the lobby). Hold E on ore rocks to
	mine them. Craft Machine Cores from ore: each core gives every machine
	+CoreBonus value (up to MaxCores).
]]

return {
	Center = Vector3.new(0, 400, 420),
	Ores = {
		{ Id = "Copper", Name = "Copper", Color = Color3.fromRGB(210, 120, 60), Count = 12, MineTime = 1, Respawn = 15, Amount = { 2, 4 } },
		{ Id = "Crystal", Name = "Crystal", Color = Color3.fromRGB(120, 220, 255), Count = 7, MineTime = 2, Respawn = 30, Amount = { 1, 2 } },
		{ Id = "Uranium", Name = "Uranium", Color = Color3.fromRGB(90, 255, 60), Count = 3, MineTime = 3, Respawn = 60, Amount = { 1, 1 } },
	},
	CoreRecipe = { Copper = 30, Crystal = 10, Uranium = 2 },
	CoreBonus = 0.1,
	MaxCores = 10,
	SellPrices = { Copper = 50, Crystal = 300, Uranium = 2500 }, -- per ore, x rebirth multiplier
	LobbyPortal = Vector3.new(120, 0, -20),
}
