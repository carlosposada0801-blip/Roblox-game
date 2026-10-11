--[[
	HudController
	Basic cash and plot display. It only reads values the server replicates
	(leaderstats + player attributes) and never sends cash to the server.
	Step 8 replaces this with the polished UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))

local player = Players.LocalPlayer

local HudController = {}

local function createLabel(parent, name, position)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = position
	label.Size = UDim2.fromOffset(240, 44)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	return label
end

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local cashLabel = createLabel(gui, "Cash", UDim2.new(0, 16, 1, -16))
	local plotLabel = createLabel(gui, "Plot", UDim2.new(0, 16, 1, -68))
	plotLabel.TextColor3 = Color3.new(1, 1, 1)
	plotLabel.Text = "Loading your factory..."

	local function updatePlot()
		local plotId = player:GetAttribute("PlotId")
		if plotId then
			plotLabel.Text = "Your factory: Plot " .. plotId
		end
	end
	player:GetAttributeChangedSignal("PlotId"):Connect(updatePlot)
	updatePlot()

	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local function updateCash()
		cashLabel.Text = Format.cash(cash.Value)
	end
	cash.Changed:Connect(updateCash)
	updateCash()
end

return HudController
