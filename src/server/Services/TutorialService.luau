--[[
	TutorialService
	The client walks new players through their first purchases
	(TutorialConfig). When it reports TutorialDone, the server checks the
	player really reached the last step (owns its item) and gives the reward once.
	Attribute: TutorialDone
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TutorialConfig)

local DataService, EconomyService, PlayerService, Net

local TutorialService = {}

local function finish(player)
	local data = DataService:GetData(player)
	if not data or data.TutorialDone then
		return
	end
	local lastStep = TutorialConfig.Steps[#TutorialConfig.Steps]
	if lastStep.Owns and not data.Unlocked[lastStep.Owns] then
		return
	end
	data.TutorialDone = true
	player:SetAttribute("TutorialDone", true)
	local text = EconomyService:GrantReward(player, TutorialConfig.Reward, false)
	Net:Notify(player, "🎓 Tutorial complete! " .. text .. ". You're on your own now, boss!", "special")
	Net:Fire(player, "Fx", "Confetti")
	Net:Fire(player, "Sfx", "Rebirth")
end

function TutorialService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function TutorialService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		local data = DataService:GetData(player)
		-- Players who already built a factory don't need the tutorial
		if data and not data.TutorialDone and (data.Rebirths > 0 or data.Unlocked.Dropper2) then
			data.TutorialDone = true
		end
		player:SetAttribute("TutorialDone", data and data.TutorialDone or false)
	end)
	Net:On("TutorialDone", finish, 0.2, 1)
end

return TutorialService
