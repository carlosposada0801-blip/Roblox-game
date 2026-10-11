--[[
	TutorialController
	Walks new players through their first minutes (TutorialConfig). Shows a
	card at the bottom of the screen with the current step; the guide arrow
	already points at the next button. When the last step is done it tells
	the server (TutorialDone), which re-checks and gives the reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TutorialConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TutorialConfig"))
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local TutorialController = {}

function TutorialController:Start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	task.wait(1)
	if player:GetAttribute("TutorialDone") then
		return
	end

	local items = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. player:GetAttribute("PlotId")):WaitForChild("Items")

	local card = UIKit.card({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(520, 76),
		BackgroundColor3 = Theme.Background,
		Parent = UIKit.root(),
	}, Theme.Accent)
	local stepLabel = UIKit.label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 18), Font = Theme.Title, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = card })
	local text = UIKit.label({ Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 44), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
	local scale = UIKit.create("UIScale", { Parent = card })

	local collected = false
	Net.On("CashPopup", function()
		collected = true
	end)

	for index, step in ipairs(TutorialConfig.Steps) do
		stepLabel.Text = ("TUTORIAL  %d / %d"):format(index, #TutorialConfig.Steps)
		text.Text = step.Text
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if step.Owns then
			while not items:FindFirstChild(step.Owns) do
				task.wait(0.3)
			end
		elseif step.Collect then
			collected = false
			while not collected do
				task.wait(0.3)
			end
		end
	end

	Net.Fire("TutorialDone")
	text.Text = "You did it! Keep building, and check out the menu on the left for more. 🎉"
	stepLabel.Text = "TUTORIAL COMPLETE"
	task.wait(5)
	card:Destroy()
end

return TutorialController
