--[[
	EnvironmentController
	Day/night cycle. Each client sets its own Lighting.ClockTime from the
	server clock, so every player sees the same time of day without the
	server sending updates every frame.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SceneryConfig"))

local EnvironmentController = {}

function EnvironmentController:Start()
	local dayNight = SceneryConfig.DayNight
	if not dayNight.Enabled then
		return
	end

	local cycleSeconds = dayNight.DayLengthMinutes * 60
	local startHour = SceneryConfig.Lighting.ClockTime

	RunService.RenderStepped:Connect(function()
		local progress = (workspace:GetServerTimeNow() % cycleSeconds) / cycleSeconds
		Lighting.ClockTime = (startHour + progress * 24) % 24
	end)
end

return EnvironmentController
