--[[
	ButtonController
	Visual feedback for your own buy buttons: green when you can afford it,
	red when you can't, and a red flash when the server turns a purchase down.
	Purely cosmetic. The server decides every purchase.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local AFFORDABLE = Color3.fromRGB(60, 220, 100)
local TOO_EXPENSIVE = Color3.fromRGB(230, 70, 70)
local FLASH = Color3.fromRGB(255, 255, 255)

local ButtonController = {}

function ButtonController:Start()
	local plotId = player:GetAttribute("PlotId")
	while not plotId do
		player:GetAttributeChangedSignal("PlotId"):Wait()
		plotId = player:GetAttribute("PlotId")
	end

	local plotModel = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotId)
	local buttons = plotModel:WaitForChild("Buttons")
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")

	local function colorFor(button)
		local price = button:GetAttribute("Price") or 0
		return if cash.Value >= price then AFFORDABLE else TOO_EXPENSIVE
	end

	local function tint(button)
		local pad = button:FindFirstChild("Pad")
		if pad then
			pad.Color = colorFor(button)
		end
	end

	local function hook(button)
		local pad = button:WaitForChild("Pad", 10)
		if not pad then
			return
		end
		tint(button)

		button:GetAttributeChangedSignal("Denied"):Connect(function()
			pad.Color = FLASH
			TweenService:Create(pad, TweenInfo.new(0.4), { Color = TOO_EXPENSIVE }):Play()
			task.delay(0.45, tint, button)
		end)
	end

	buttons.ChildAdded:Connect(hook)
	for _, button in ipairs(buttons:GetChildren()) do
		task.spawn(hook, button)
	end

	cash.Changed:Connect(function()
		for _, button in ipairs(buttons:GetChildren()) do
			tint(button)
		end
	end)
end

return ButtonController
