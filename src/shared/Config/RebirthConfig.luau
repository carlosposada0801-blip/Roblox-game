--[[
	RebirthConfig
	Rebirthing resets cash and every bought item, and gives a permanent cash
	multiplier. Workers, robots, Prototypes and game passes are kept.
]]

local RebirthConfig = {}

RebirthConfig.BaseCost = 150000 -- cash needed for the first rebirth (tuned with /balance)
RebirthConfig.CostGrowth = 1.75 -- each rebirth costs this much more than the last
RebirthConfig.MultiplierPerRebirth = 0.5 -- +0.5x cash per rebirth (1x, 1.5x, 2x, ...)

-- Global top-rebirths board in the lobby
RebirthConfig.LeaderboardStore = "RebirthLeaderboard_v1"
RebirthConfig.LeaderboardSize = 10
RebirthConfig.LeaderboardRefresh = 60 -- seconds

function RebirthConfig.GetCost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirths)
end

function RebirthConfig.GetMultiplier(rebirths: number): number
	return 1 + rebirths * RebirthConfig.MultiplierPerRebirth
end

return RebirthConfig
