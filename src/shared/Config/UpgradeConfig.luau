--[[
	UpgradeConfig
	Droppers and machines can be levelled up by walking up to them and using
	the "Upgrade" prompt. Levels reset on rebirth.

	Cost to go from level L to L+1 = max(MinBaseCost, item price) * CostScale * CostGrowth ^ (L - 1)
]]

return {
	MaxLevel = 5,
	MinBaseCost = 100,
	CostScale = 1.5,
	CostGrowth = 2,

	Dropper = {
		ValuePerLevel = 0.4, -- +40% item value per level
		SpeedPerLevel = 0.1, -- +10% drop speed per level
	},
	Machine = {
		MultiplierPerLevel = 0.25, -- +25% of the machine's bonus per level
	},
}
