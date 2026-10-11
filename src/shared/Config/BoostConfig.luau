--[[
	BoostConfig
	Short timed boosts (from quests, codes, the Starter Pack...). A reward
	table gives one with Boost = { Id = "CashX2", Minutes = 10 }. Getting
	the same boost again adds time. Boost time only runs while you're in
	the game, so nobody loses a boost by logging off.
]]

return {
	MaxMinutes = 240, -- a boost can't stack beyond this
	Boosts = {
		CashX2 = { Name = "2x Cash", Icon = "💰", CashMultiplier = 2, Color = Color3.fromRGB(80, 230, 110) },
		Turbo = { Name = "Turbo Droppers", Icon = "⏩", DropperMultiplier = 1.5, Color = Color3.fromRGB(0, 200, 255) },
		Lucky = { Name = "Lucky Line", Icon = "🍀", PrototypeChanceMultiplier = 3, Color = Color3.fromRGB(255, 120, 255) },
	},
}
