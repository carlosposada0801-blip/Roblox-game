--[[
	TutorialController
	Walks new players through their first minutes (TutorialConfig): a card
	at the bottom of the screen with the current step, a Skip button, and a
	bouncing arrow over the exact button / pad to use (or next to the
	REBIRTH menu button). Each finished step is reported to the server
	(TutorialProgress), which checks it and saves it, so the tutorial picks
	up where it left off and never repeats.
	While the tutorial runs, the small guide arrow (GuideController) is hidden.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TutorialConfig = require(Shared:WaitForChild("Config"):WaitForChild("TutorialConfig"))
local RebirthConfig = require(Shared.Config.RebirthConfig)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local TutorialController = {}

local function makeWorldArrow()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrow"
	billboard.Size = UDim2.fromOffset(70, 90)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0
	label.Text = "⬇"
	label.Parent = billboard
	billboard.Parent = player:WaitForChild("PlayerGui")
	return billboard
end

function TutorialController:Start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	task.wait(1)
	if player:GetAttribute("TutorialDone") then
		return
	end

	local plot = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. player:GetAttribute("PlotId"))
	local items = plot:WaitForChild("Items")
	local buttons = plot:WaitForChild("Buttons")
	local rebirths = player:WaitForChild("leaderstats"):WaitForChild("Rebirths")
	local cash = player.leaderstats:WaitForChild("Cash")

	local card = UIKit.card({
		Name = "TutorialCard",
		-- Phones: near the top so it doesn't cover the thumbstick or jump button
		AnchorPoint = if UIKit.IsTouch then Vector2.new(0.5, 0) else Vector2.new(0.5, 1),
		Position = if UIKit.IsTouch then UDim2.new(0.5, 0, 0, 180) else UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(560, 80),
		BackgroundColor3 = Theme.Background,
		Parent = UIKit.root(),
	}, Theme.Accent)
	local stepLabel = UIKit.label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -130, 0, 18), Font = Theme.Title, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = card })
	local text = UIKit.label({ Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -130, 0, 46), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
	local scale = UIKit.create("UIScale", { Parent = card })
	local skipped = false
	UIKit.button({
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(100, 44),
		Color = Theme.Disabled,
		Text = "SKIP",
		Parent = card,
	}, function()
		UIKit.confirm("Skip tutorial?", "You can still follow the small guide arrow. The tutorial won't come back.", "Skip", function()
			skipped = true
			Net.Fire("TutorialProgress", "Skip")
		end)
	end)

	-- Pointers: one in the world, one on the screen (for the menu button)
	local worldArrow = makeWorldArrow()
	local screenArrow = UIKit.label({
		Name = "TutorialPointer",
		Size = UDim2.fromOffset(60, 60),
		Text = "👈",
		MaxTextSize = 50,
		Visible = false,
		ZIndex = 20,
		Parent = UIKit.root(),
	})
	local bounce = RunService.RenderStepped:Connect(function()
		local t = os.clock() * 5
		worldArrow.StudsOffset = Vector3.new(0, 6 + math.abs(math.sin(t)) * 2, 0)
		local menu = UIKit.root():FindFirstChild("Menu")
		local menuButton = menu and menu:FindFirstChild("Rebirth")
		if screenArrow.Visible and menuButton then
			screenArrow.Position = UDim2.fromOffset(
				menuButton.AbsolutePosition.X + menuButton.AbsoluteSize.X + 4 + math.abs(math.sin(t)) * 12,
				menuButton.AbsolutePosition.Y + menuButton.AbsoluteSize.Y / 2 - 30
			)
		end
	end)

	local collected = false
	local collectConnection = Net.On("CashPopup", function()
		collected = true
	end)

	player:SetAttribute("TutorialActive", true) -- local only: hides the guide arrow
	local first = (player:GetAttribute("TutorialStep") or 0) + 1
	for index = first, #TutorialConfig.Steps do
		local step = TutorialConfig.Steps[index]
		stepLabel.Text = ("TUTORIAL  %d / %d"):format(index, #TutorialConfig.Steps)
		text.Text = step.Text
		card.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

		if step.Owns then
			while not skipped and not items:FindFirstChild(step.Owns) do
				local button = buttons:FindFirstChild("Button_" .. step.Owns)
				worldArrow.Adornee = button and button:FindFirstChild("Pad")
				worldArrow.Enabled = worldArrow.Adornee ~= nil
				task.wait(0.3)
			end
		elseif step.Collect then
			collected = false
			while not skipped and not collected and not player:GetAttribute("Pass_AutoCollect") do
				local pad = items:FindFirstChild("CashPad", true)
				worldArrow.Adornee = pad
				worldArrow.Enabled = pad ~= nil
				task.wait(0.3)
			end
		elseif step.Rebirth then
			-- Hide until a rebirth is affordable, then point at the menu button
			worldArrow.Enabled = false
			card.Visible = false
			player:SetAttribute("TutorialActive", false)
			while not skipped and rebirths.Value == 0 and cash.Value < RebirthConfig.GetCost(0) do
				task.wait(1)
			end
			player:SetAttribute("TutorialActive", true)
			card.Visible = true
			screenArrow.Visible = true
			while not skipped and rebirths.Value == 0 do
				task.wait(0.5)
			end
			screenArrow.Visible = false
		end
		if skipped then
			break
		end
		worldArrow.Enabled = false
		Net.Fire("TutorialProgress", index)
	end

	collectConnection:Disconnect()
	player:SetAttribute("TutorialActive", false)
	worldArrow:Destroy()
	screenArrow:Destroy()
	bounce:Disconnect()
	if skipped then
		card:Destroy()
		return
	end
	stepLabel.Text = "TUTORIAL COMPLETE"
	text.Text = "You did it! Keep building, and check out the menu on the left for more. 🎉"
	task.wait(5)
	card:Destroy()
end

return TutorialController
