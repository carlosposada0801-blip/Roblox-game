--[[
	AchievementService
	Checks every player's stats every few seconds and unlocks achievements
	(AchievementConfig). Each unlock can award a Roblox badge (BadgeId) and
	unlocks a Title. Attribute AchievementsJson = { [id] = true }.
]]

local BadgeService = game:GetService("BadgeService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementConfig = require(Shared.Config.AchievementConfig)
local PetConfig = require(Shared.Config.PetConfig)

local DataService, PlayerService, Net

local AchievementService = {}
AchievementService.Unlocked = require(Shared.Util.Signal).new() -- (player, achievement)

-- Stats that aren't plain save-data numbers
local function statValue(data, stat)
	if stat == "LegendaryRobots" then
		local count = 0
		for key, sold in pairs(data.Collection) do
			if string.sub(key, 1, 10) == "Legendary|" then
				count += sold
			end
		end
		return count
	elseif stat == "BookEntries" then
		local count = 0
		for _ in pairs(data.Collection) do
			count += 1
		end
		return count
	elseif stat == "MythicPets" then
		local count = 0
		for _, pet in ipairs(data.Pets) do
			local info = PetConfig.Pets[pet.Type]
			if info and info.Rarity == "Mythic" then
				count += 1
			end
		end
		return count
	end
	return tonumber(data[stat]) or 0
end

local function sync(player)
	local data = DataService:GetData(player)
	if data then
		local unlocked = {}
		for id in pairs(data.Achievements) do
			unlocked[id] = true
		end
		player:SetAttribute("AchievementsJson", HttpService:JSONEncode(unlocked))
	end
end

function AchievementService:Check(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local changed = false
	for _, achievement in ipairs(AchievementConfig.Achievements) do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = os.time()
			changed = true
			Net:Notify(player, ("🏅 Achievement unlocked: %s! New title: %s"):format(achievement.Name, achievement.Title), "special")
			Net:Fire(player, "Sfx", "Rebirth")
			Net:Fire(player, "Fx", "Confetti")
			if achievement.BadgeId and achievement.BadgeId ~= 0 then
				task.spawn(pcall, BadgeService.AwardBadge, BadgeService, player.UserId, achievement.BadgeId)
			end
			self.Unlocked:Fire(player, achievement)
		end
	end
	if changed then
		sync(player)
	end
end

function AchievementService:Has(player: Player, id: string): boolean
	local data = DataService:GetData(player)
	return data ~= nil and data.Achievements[id] ~= nil
end

-- Awards badges for achievements unlocked before their BadgeId was filled in
-- (or when an earlier award failed). AwardBadge does nothing if they own it.
local function catchUpBadges(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for _, achievement in ipairs(AchievementConfig.Achievements) do
		if achievement.BadgeId and achievement.BadgeId ~= 0 and data.Achievements[achievement.Id] and player.Parent then
			local ok, owned = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, achievement.BadgeId)
			if ok and not owned then
				pcall(BadgeService.AwardBadge, BadgeService, player.UserId, achievement.BadgeId)
			end
			task.wait(0.5) -- stay well under the badge request limits
		end
	end
end

function AchievementService:Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService
	Net = services.Net
end

function AchievementService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		sync(player)
		self:Check(player)
		task.spawn(catchUpBadges, player)
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("DataLoaded") then
					self:Check(player)
				end
			end
		end
	end)
end

return AchievementService
