--[[
	DataConfig
	DataStore settings and the default save file for a brand-new player.
	Any key you add to Template is filled in automatically for existing
	players the next time they join (see DataService's reconcile step).
]]

local DataConfig = {}

-- Change the version suffix to start every player over from scratch.
DataConfig.StoreName = "RobotFactoryTycoon_v1"
DataConfig.KeyPrefix = "Player_"

DataConfig.AutosaveInterval = 60 -- seconds between saves (also refreshes the session lock)
DataConfig.LockExpireSeconds = 180 -- a lock older than this is treated as a dead server
DataConfig.LoadAttempts = 6 -- the final attempt takes the lock even if another server still holds it
DataConfig.LoadRetryDelay = 4 -- seconds between load attempts
DataConfig.SaveAttempts = 3

-- In Studio, true = always use an in-memory store (nothing persists between play tests).
-- When false, Studio uses the real DataStore if "Enable Studio Access to API Services"
-- is on, and falls back to the in-memory store otherwise.
DataConfig.ForceMockInStudio = false

DataConfig.Template = {
	Cash = 0,
	PendingCash = 0, -- earned but not yet collected from the cash pad
	TotalEarned = 0,
	Rebirths = 0,
	Unlocked = {}, -- [itemId] = true
	Workers = {}, -- [workerId] = number hired
	Robots = 0, -- robots available to hire workers with
	RobotsBuilt = 0, -- lifetime robots sold
	Prototypes = 0, -- Prototype robots owned (arena)
	ProcessedReceipts = {}, -- [purchaseId] = os.time(), stops double grants
}

return DataConfig
