--[[
	BoostService
	Timed boosts (BoostConfig) from quests, codes and the Starter Pack.
	Saved as data.Boosts = { [boostId] = seconds left }. Time only counts
	down while the player is in the game.
	Attributes: Boost_<id> = seconds left (0 when inactive).
	Other services ask GetValue(player, key, default), e.g. "CashMultiplier".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.BoostConfig)

local DataService, EconomyService, PlayerService, Net

local BoostService = {}

local function sync(player, data)
	for id in pairs(BoostConfig.Boosts) do
		player:SetAttribute("Boost_" .. id, math.floor(tonumber(data.Boosts[id]) or 0))
	end
end

-- Adds minutes to a boost. Returns true if the boost exists.
function BoostService:Give(player: Player, id: string, minutes: number): boolean
	local data = DataService:GetData(player)
	local boost = BoostConfig.Boosts[id]
	if not (data and boost) or type(minutes) ~= "number" or minutes <= 0 then
		return false
	end
	local wasActive = (data.Boosts[id] or 0) > 0
	data.Boosts[id] = math.min(BoostConfig.MaxMinutes * 60, (data.Boosts[id] or 0) + minutes * 60)
	sync(player, data)
	if not wasActive then
		EconomyService:Refresh(player)
	end
	return true
end

-- Product of an effect across active boosts (e.g. "CashMultiplier"), or default.
function BoostService:GetValue(player: Player, key: string, default: number): number
	local data = DataService:GetData(player)
	local value = default
	if data then
		for id, seconds in pairs(data.Boosts) do
			local boost = BoostConfig.Boosts[id]
			if boost and seconds > 0 and boost[key] then
				value *= boost[key]
			end
		end
	end
	return value
end

function BoostService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function BoostService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		local data = DataService:GetData(player)
		if data then
			sync(player, data)
		end
	end)

	-- Count down once a second for everyone in the game
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = player:GetAttribute("DataLoaded") and DataService:GetData(player)
				if data then
					local ended = false
					for id, seconds in pairs(data.Boosts) do
						if seconds > 0 then
							data.Boosts[id] = math.max(0, seconds - 1)
							if data.Boosts[id] == 0 then
								ended = true
								local boost = BoostConfig.Boosts[id]
								Net:Notify(player, ("%s %s boost ended."):format(boost and boost.Icon or "", boost and boost.Name or id), "info")
							end
						end
						if data.Boosts[id] == 0 then
							data.Boosts[id] = nil
						end
					end
					sync(player, data)
					if ended then
						EconomyService:Refresh(player)
					end
				end
			end
		end
	end)
end

return BoostService
