--[[
	RobotBookService
	Rolls a rarity for every robot built (RarityConfig) and records every
	Rarity + Color combination the player sells in their Robot Collection
	Book (data.Collection). Each entry adds a permanent cash bonus.
	Attributes: CollectionJson (counts by key), CollectionBonus.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.RarityConfig)

local DataService, EconomyService, PlayerService, QuestService, Net

local RobotBookService = {}

local totalWeight = 0
for _, rarity in ipairs(RarityConfig.Rarities) do
	totalWeight += rarity.Weight
end

function RobotBookService:RollRarity()
	local roll = math.random() * totalWeight
	for _, rarity in ipairs(RarityConfig.Rarities) do
		roll -= rarity.Weight
		if roll <= 0 then
			return rarity
		end
	end
	return RarityConfig.Rarities[1]
end

local function entryCount(data)
	local count = 0
	for _ in pairs(data.Collection) do
		count += 1
	end
	return count
end

function RobotBookService:GetMultiplier(player: Player): number
	local data = DataService:GetData(player)
	return 1 + (data and entryCount(data) or 0) * RarityConfig.BonusPerEntry
end

local function sync(player)
	local data = DataService:GetData(player)
	if data then
		player:SetAttribute("CollectionJson", HttpService:JSONEncode(data.Collection))
		player:SetAttribute("CollectionBonus", entryCount(data) * RarityConfig.BonusPerEntry)
	end
end

-- Called when a robot is sold
function RobotBookService:Record(player: Player, rarityId: string, colorName: string)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local key = rarityId .. "|" .. colorName
	local isNew = data.Collection[key] == nil
	data.Collection[key] = (data.Collection[key] or 0) + 1
	if isNew then
		Net:Notify(player, ("📖 New robot for your book: %s %s! (+%d%% cash)"):format(rarityId, colorName, RarityConfig.BonusPerEntry * 100), "special")
		EconomyService:Refresh(player)
	end
	if rarityId ~= "Common" and rarityId ~= "Uncommon" then
		QuestService:Track(player, "RareRobots", 1)
	end
	sync(player)
end

function RobotBookService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	Net = services.Net
end

function RobotBookService:Start()
	PlayerService.PlayerReady:Connect(sync)
end

return RobotBookService
