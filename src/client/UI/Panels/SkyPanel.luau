--[[
	SkyPanel
	Sky Factory info: how to unlock it, and buttons to fly up / go home.
	The blue pad in your factory does the same thing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkyConfig"))
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local SkyPanel = {}

function SkyPanel.build()
	local window, content = UIKit.window("☁️ SKY FACTORY", Theme.Cyan, Vector2.new(500, 360))
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 120),
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		MaxTextSize = 18,
		Text = ("A second factory on a floating island! New machines (Sky Laser Cutter, AI Core Installer, Quantum Assembler) build Sky Androids and Titan Mechs worth WAY more. Its progress and upgrades are saved separately and are never reset by rebirths.\n\nUnlocks at %d rebirths."):format(SkyConfig.UnlockRebirths),
		Parent = content,
	})
	local status = UIKit.label({ Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 34), Font = Theme.Title, MaxTextSize = 24, Parent = content })
	local go = UIKit.button({
		Name = "GoToSky",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, -6, 0, 56),
		Color = Theme.Cyan,
		Text = "⬆ FLY UP",
		Parent = content,
	}, function()
		Net.Fire("SkyAction", "Go")
		window.Visible = false
	end)
	UIKit.button({
		Name = "Home",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, -6, 0, 56),
		Color = Theme.Green,
		Text = "🏠 MY FACTORY",
		Parent = content,
	}, function()
		Net.Fire("SkyAction", "Home")
		window.Visible = false
	end)
	local function update()
		local unlocked = player:GetAttribute("SkyUnlocked") == true
		status.Text = if unlocked then "✅ Unlocked!" else ("🔒 Locked: %d / %d rebirths"):format(player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Rebirths") and player.leaderstats.Rebirths.Value or 0, SkyConfig.UnlockRebirths)
		status.TextColor3 = if unlocked then Theme.Green else Theme.Accent
		go:SetAttribute("Disabled", not unlocked)
	end
	player:GetAttributeChangedSignal("SkyUnlocked"):Connect(update)
	window:GetPropertyChangedSignal("Visible"):Connect(update)
	update()
	return window
end

return SkyPanel
