--[[
	CodesConfig
	Promo codes players type into the Codes window. Codes are not case
	sensitive. Each player can use each code once.
	  Reward  = reward table: Cash, Robots, Prototypes, Boost = { Id, Minutes }, Skin = "SkinId"
	  Expires = { Year, Month, Day } (UTC midnight that ends the code), or nil for never
	  ScaleCash = true multiplies Cash by the player's rebirth multiplier
	Add a new code here whenever you post an update!
]]

return {
	Codes = {
		RELEASE = { Reward = { Cash = 5000, Boost = { Id = "CashX2", Minutes = 15 }, Skin = "SkinRelease" }, ScaleCash = true },
		ROBOTS = { Reward = { Robots = 10 } },
		TURBO = { Reward = { Boost = { Id = "Turbo", Minutes = 20 } } },
		HALLOWEEN2026 = { Reward = { Cash = 25000 }, ScaleCash = true, Expires = { Year = 2026, Month = 11, Day = 1 } },
		OLDCODE = { Reward = { Cash = 1 }, Expires = { Year = 2025, Month = 1, Day = 1 } }, -- example of an expired code
	},
}
