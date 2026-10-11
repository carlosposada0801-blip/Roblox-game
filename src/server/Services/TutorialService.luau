--[[
	TutorialService
	Saves tutorial progress (TutorialConfig). The client reports each step
	it finishes with TutorialProgress(step); the server only accepts it if
	the step really is done (owns the item, has collected cash, has
	rebirthed) and never moves backwards. TutorialProgress("Skip") ends it.
	The reward is given once, after RewardAfterStep.
	Attributes: TutorialStep (steps finished), TutorialDone
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TutorialConfig)

local DataService, EconomyService, PlayerService, Net

local TutorialService = {}

local function isStepDone(data, step)
	if step.Owns then
		return data.Unlocked[step.Owns] == true
	elseif step.Collect then
		return data.TotalEarned > 0
	elseif step.Rebirth then
		return data.Rebirths > 0
	end
	return true
end

local function sync(player, data)
	player:SetAttribute("TutorialStep", data.TutorialStep)
	player:SetAttribute("TutorialDone", data.TutorialDone)
end

local function progress(player, value)
	local data = DataService:GetData(player)
	if not data or data.TutorialDone then
		return
	end
	if value == "Skip" then
		data.TutorialDone = true
		sync(player, data)
		Net:Notify(player, "Tutorial skipped. Follow the small arrow if you get lost!", "info")
		return
	end
	if type(value) ~= "number" then
		return
	end
	-- Advance through every finished step up to the reported one
	local target = math.clamp(math.floor(value), 0, #TutorialConfig.Steps)
	while data.TutorialStep < target and isStepDone(data, TutorialConfig.Steps[data.TutorialStep + 1]) do
		data.TutorialStep += 1
		if data.TutorialStep == TutorialConfig.RewardAfterStep then
			local text = EconomyService:GrantReward(player, TutorialConfig.Reward, false)
			Net:Notify(player, "🎓 Factory basics done! " .. text .. ". You're a real boss now!", "special")
			Net:Fire(player, "Fx", "Confetti")
			Net:Fire(player, "Sfx", "Rebirth")
		end
	end
	if data.TutorialStep >= #TutorialConfig.Steps then
		data.TutorialDone = true
	end
	sync(player, data)
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
		if not data then
			return
		end
		-- Players who already rebirthed don't need the tutorial
		if not data.TutorialDone and data.Rebirths > 0 then
			data.TutorialDone = true
		end
		sync(player, data)
	end)
	Net:On("TutorialProgress", progress, 2, 4)
end

return TutorialService
