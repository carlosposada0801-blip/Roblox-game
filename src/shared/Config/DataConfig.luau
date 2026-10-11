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
	ArenaWins = 0,
	Kills = 0, -- PvP knockouts anywhere
	Weapons = { RoboSword = true }, -- [weaponId] = true when unlocked
	Likes = 0, -- likes other players gave your factory
	LikesGiven = { Day = 0, Ids = {} }, -- who you've liked today
	Levels = {}, -- [itemId] = upgrade level (reset on rebirth)
	Collection = {}, -- ["Rarity|Color"] = robots sold
	Pets = {}, -- list of { Id = number, Type = petType, Equipped = bool }
	NextPetId = 1,
	Daily = { LastDay = 0, Streak = 0 },
	Quests = { Day = 0, List = {} },
	Settings = {
		GuideArrow = true, -- arrow pointing at the next thing to buy
		Music = true,
		Sfx = true,
		ScreenShake = true,
	},
	TutorialDone = false,
	Ascensions = 0, -- prestige level (AscensionConfig)
	Achievements = {}, -- [achievementId] = os.time()
	Cosmetics = { Title = "", Trail = "", Accent = "", Skin = "" }, -- equipped
	OwnedCosmetics = {}, -- [cosmeticId] = true (bought; achievement ones unlock automatically)
	BossKills = 0, -- boss raids won
	DroneKills = 0, -- rogue drones destroyed
	RaceWins = 0,
	RaceBotLevel = 1,
	ContractsDone = 0,
	Ores = { Copper = 0, Crystal = 0, Uranium = 0 },
	Cores = 0, -- crafted Machine Cores (+value to every machine)
	Crew = "", -- crew name (CrewService)
	StarterPackBought = false,

	-- v2.3
	TutorialStep = 0, -- tutorial progress, so it continues where you left off
	Sessions = 0, -- times joined (Starter Pack offer)
	PlayTime = 0, -- seconds played, all sessions
	Boosts = {}, -- [boostId] = seconds left (BoostConfig)
	RedeemedCodes = {}, -- [CODE] = os.time()
	GroupRewardClaimed = false,
	OwnedTitles = {}, -- [title] = true, titles not from achievements (weekly winners)
	Trades = 0, -- completed trades
	BattleWins = 0, -- robot battle arena (BattleConfig)
	BattleLosses = 0,
	WeeklyClaimed = {}, -- [tostring(week)] = true, weekly top-3 prizes already given
	Weekly = { Week = 0, Earned = 0 }, -- cash earned this week (weekly leaderboard)
	Custom = { Wall = "", Floor = "", Machine = "", Sign = "", Decor = {} }, -- factory customization
	OwnedCustom = {}, -- [customId] = true
	Yard = {}, -- logistics yard pieces: ["x,y"] = { Type, Rot }
	SkyUnlocked = 0, -- 1 once the Sky Factory is unlocked
	Sky = { Unlocked = {}, Levels = {} }, -- Sky Factory progress, kept through rebirths
}

return DataConfig
