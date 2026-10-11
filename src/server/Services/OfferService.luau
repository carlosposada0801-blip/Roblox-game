--[[
	OfferService
	Decides when to pop up the Starter Pack offer (MonetizationConfig.StarterOffer):
	  * first session: after FirstSessionDelay seconds of play
	  * second session: shortly after joining, if they still haven't bought it
	  * never again after that, and never once it's bought
	Also counts sessions (data.Sessions) and total play time (data.PlayTime).
	The client shows the popup when it gets ShowOffer("StarterPack").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.MonetizationConfig)

local DataService, PlayerService, Net

local OfferService = {}

local joinedAt = {} -- [Player] = os.clock()

local function offerStarterPack(player, delay)
	task.delay(delay, function()
		local data = player.Parent and DataService:GetData(player)
		if data and not data.StarterPackBought then
			Net:Fire(player, "ShowOffer", "StarterPack")
		end
	end)
end

function OfferService:Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService
	Net = services.Net
end

function OfferService:Start()
	local offer = MonetizationConfig.StarterOffer
	PlayerService.PlayerReady:Connect(function(player)
		local data = DataService:GetData(player)
		if not data then
			return
		end
		data.Sessions += 1
		joinedAt[player] = os.clock()
		if data.Sessions == 1 then
			offerStarterPack(player, offer.FirstSessionDelay)
		elseif data.Sessions == 2 then
			offerStarterPack(player, offer.SecondSessionDelay)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
	end)

	-- Play time, added once a minute
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(joinedAt) do
				local data = DataService:GetData(player)
				if data then
					data.PlayTime += 60
				end
			end
		end
	end)
end

return OfferService
