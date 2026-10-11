--[[
	SkyConfig
	Sky Factory: a second world on a floating island high above each plot.
	Unlocks at UnlockRebirths. A teleport pad in your factory takes you up;
	a pad on the island brings you back. The island has its own items
	(ItemConfig entries with World = "Sky"), its own upgrades, and new
	robot types worth much more. Sky progress is saved separately
	(data.Sky) and is NOT reset by rebirths.
]]

return {
	UnlockRebirths = 8,
	Height = 220, -- studs above the plot floor
	IslandSize = Vector3.new(110, 6, 110),
	GroundPad = Vector3.new(22, 0, 6), -- plot-local position of the teleport pad in your factory
	ReturnPad = Vector3.new(0, 0, 44), -- island-local position of the pad back down
	Spawn = Vector3.new(0, 4, 36), -- island-local arrival spot
}
