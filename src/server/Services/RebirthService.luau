--[[
	RebirthService
	RequestRebirth (client asks, server decides): needs cash >= the rebirth
	cost. Resets cash, pending cash, every bought item and upgrade levels;
	adds 1 rebirth, which raises the permanent cash multiplier (RebirthConfig).
	Workers, robots, Prototypes, pets, the collection book and game passes are kept.
	Rebirths show in the player list and on the Top Rebirths board (LeaderboardService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, TycoonService, LeaderboardService, Net

local RebirthService = {}

local function requestRebirth(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local cost = RebirthConfig.GetCost(data.Rebirths)
	if data.Cash < cost then
		Net:Notify(player, ("You need %s to rebirth."):format(Format.cash(cost)), "error")
		return
	end

	data.Cash = 0
	data.PendingCash = 0
	data.Levels = {}
	data.Rebirths += 1

	TycoonService:ResetTycoon(player)
	EconomyService:Refresh(player)
	LeaderboardService:SaveScores(player)
	task.spawn(DataService.SaveAsync, DataService, player)

	local multiplier = RebirthConfig.GetMultiplier(data.Rebirths)
	Net:Fire(player, "Sfx", "Rebirth")
	Net:Fire(player, "Fx", "Rebirth")
	Net:Notify(player, ("Rebirth %d! Cash is now x%s forever."):format(data.Rebirths, tostring(multiplier)), "special")
	Net:NotifyAll(("%s rebirthed! (Rebirth %d)"):format(player.DisplayName, data.Rebirths), "info")
end

function RebirthService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	LeaderboardService = services.LeaderboardService
	Net = services.Net
end

function RebirthService:Start()
	Net:On("RequestRebirth", requestRebirth, 0.5, 1)
end

return RebirthService
