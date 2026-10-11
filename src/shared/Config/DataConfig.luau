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
	TotalEarned = 0,
	Rebirths = 0,
	Unlocked = {}, -- [buttonId] = true                    (step 2)
	Workers = {}, -- list of hired robot workers           (step 6)
	RobotsBuilt = 0, --                                    (step 4)
	Prototypes = 0, --                                     (step 9)
	ProcessedReceipts = {}, -- [purchaseId] = os.time()    (step 7)
}

return DataConfig
