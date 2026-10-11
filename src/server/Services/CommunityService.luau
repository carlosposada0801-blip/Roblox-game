--[[
	CommunityService
	Group (community) membership reward (GroupConfig):
	  * members get +CashBonus cash forever (attribute InGroup)
	  * the first time we see them in the group: a one-time cash reward
	Checked when they join and whenever they press "Check" in the shop
	(CheckGroup remote), so joining mid-game works.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupConfig = require(Shared.Config.GroupConfig)

local DataService, EconomyService, PlayerService, Net

local CommunityService = {}

local function isMember(player)
	if GroupConfig.GroupId == 0 then
		return false
	end
	-- IsInGroupAsync asks Roblox again (IsInGroup caches the answer from when they joined)
	local ok, result = pcall(player.IsInGroupAsync, player, GroupConfig.GroupId)
	if not ok then
		ok, result = pcall(player.IsInGroup, player, GroupConfig.GroupId)
	end
	return ok and result == true
end

local function check(player, fromButton)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if GroupConfig.GroupId == 0 then
		player:SetAttribute("GroupConfigured", false)
		if fromButton then
			Net:Notify(player, "The group isn't set up yet (GroupConfig.GroupId).", "info")
		end
		return
	end
	player:SetAttribute("GroupConfigured", true)

	local member = isMember(player)
	local was = player:GetAttribute("InGroup") == true
	player:SetAttribute("InGroup", member)
	if member ~= was then
		EconomyService:Refresh(player)
	end

	if member and not data.GroupRewardClaimed then
		data.GroupRewardClaimed = true
		local text = EconomyService:GrantReward(player, { Cash = GroupConfig.JoinCash }, true)
		Net:Notify(player, ("👥 Thanks for joining the group! %s and +%d%% cash forever!"):format(text, GroupConfig.CashBonus * 100), "special")
		Net:Fire(player, "Fx", "Confetti")
		Net:Fire(player, "Sfx", "Rebirth")
		task.spawn(DataService.SaveAsync, DataService, player)
	elseif fromButton then
		if member then
			Net:Notify(player, ("👥 You're in the group: +%d%% cash is active!"):format(GroupConfig.CashBonus * 100), "success")
		else
			Net:Notify(player, "Not in the group yet. Join it from the game's page (Community), then press Check again.", "error")
		end
	end
end

function CommunityService:GetMultiplier(player: Player): number
	return if player:GetAttribute("InGroup") then 1 + GroupConfig.CashBonus else 1
end

function CommunityService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function CommunityService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		check(player, false)
	end)
	Net:On("CheckGroup", function(player)
		check(player, true)
	end, 0.2, 1)
end

return CommunityService
