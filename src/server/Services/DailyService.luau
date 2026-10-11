--[[
	DailyService
	Daily login rewards with a streak (DailyConfig). The client shows a popup
	when DailyAvailable is true and sends ClaimDaily.
	Attributes: DailyAvailable, DailyStreak (streak after claiming today), DailyIndex (reward index).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DailyConfig)

local DataService, EconomyService, PlayerService, Net

local DailyService = {}

local function today()
	return os.time() // 86400
end

-- Streak the player would have if they claimed today
local function nextStreak(data)
	if data.Daily.LastDay == today() - 1 then
		return data.Daily.Streak + 1
	end
	return 1
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local available = data.Daily.LastDay < today()
	local streak = if available then nextStreak(data) else data.Daily.Streak
	player:SetAttribute("DailyAvailable", available)
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("DailyIndex", (streak - 1) % #DailyConfig.Rewards + 1)
end

local function claimDaily(player)
	local data = DataService:GetData(player)
	if not data or data.Daily.LastDay >= today() then
		return
	end
	local streak = nextStreak(data)
	data.Daily = { LastDay = today(), Streak = streak }

	local reward = DailyConfig.Rewards[(streak - 1) % #DailyConfig.Rewards + 1]
	local text = EconomyService:GrantReward(player, reward, DailyConfig.CashScalesWithRebirths)
	Net:Notify(player, ("🎁 Day %d reward: %s"):format(streak, text), "special")
	Net:Fire(player, "Sfx", "Rebirth")
	Net:Fire(player, "Fx", "Confetti")
	sync(player)
	task.spawn(DataService.SaveAsync, DataService, player)
end

function DailyService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function DailyService:Start()
	PlayerService.PlayerReady:Connect(sync)
	Net:On("ClaimDaily", claimDaily, 0.5, 1)

	-- New day while playing
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				if player:GetAttribute("DataLoaded") then
					sync(player)
				end
			end
		end
	end)
end

return DailyService
