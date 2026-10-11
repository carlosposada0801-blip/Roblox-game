--[[
	AscensionService
	Prestige (AscensionConfig): with enough rebirths you can Ascend. It
	resets rebirths, cash, upgrades and your factory, and gives a permanent
	x2 cash per ascension plus a new factory theme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AscensionConfig = require(Shared.Config.AscensionConfig)

local DataService, EconomyService, TycoonService, CosmeticService, LeaderboardService, Net

local AscensionService = {}

function AscensionService:GetTheme(ascensions: number)
	local themes = AscensionConfig.Themes
	local highest = 0
	for index in pairs(themes) do
		if index <= ascensions and index > highest then
			highest = index
		end
	end
	return themes[highest] or themes[0]
end

function AscensionService:GetMultiplier(player: Player): number
	local data = DataService:GetData(player)
	return AscensionConfig.MultiplierPerAscension ^ (data and data.Ascensions or 0)
end

local function ascend(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if data.Rebirths < AscensionConfig.RequiredRebirths then
		Net:Notify(player, ("You need %d rebirths to Ascend."):format(AscensionConfig.RequiredRebirths), "error")
		return
	end
	data.Ascensions += 1
	data.Rebirths = 0
	data.Cash = 0
	data.PendingCash = 0
	data.Levels = {}
	player:SetAttribute("Ascensions", data.Ascensions)
	TycoonService:ResetTycoon(player)
	EconomyService:Refresh(player)
	CosmeticService:ApplyPlotStyle(player)
	LeaderboardService:SaveScores(player)
	task.spawn(DataService.SaveAsync, DataService, player)

	local theme = AscensionService:GetTheme(data.Ascensions)
	Net:Fire(player, "Fx", "Rebirth")
	Net:Fire(player, "Sfx", "Rebirth")
	Net:Notify(player, ("✨ ASCENDED! Cash x%d forever. New theme: %s"):format(AscensionService:GetMultiplier(player), theme.Name), "special")
	Net:NotifyAll(("✨ %s has ASCENDED (level %d)!"):format(player.DisplayName, data.Ascensions), "special")
end

function AscensionService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	CosmeticService = services.CosmeticService
	LeaderboardService = services.LeaderboardService
	Net = services.Net
end

function AscensionService:Start()
	Net:On("Ascend", ascend, 0.2, 1)
end

return AscensionService
