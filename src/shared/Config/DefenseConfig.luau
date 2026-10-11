--[[
	DefenseConfig
	Rogue drones raid factories and drain cash from the cash pad until
	destroyed. Click/tap them (or shoot them) to destroy them for a reward.
]]

return {
	MinDelay = 150,
	MaxDelay = 300,
	DronesPerRaid = { 1, 3 },
	DroneHealth = 60,
	ClickDamage = 20,
	StealPercentPerSecond = 0.03, -- of the pad's pending cash
	Reward = 500, -- per drone, x rebirth multiplier
	MinPendingToRaid = 50, -- only raid pads with at least this much cash waiting
}
