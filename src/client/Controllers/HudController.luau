--[[
	HudController
	Top-of-screen HUD: an animated cash counter, stat pills (multiplier,
	rebirths, robots, Prototypes) and "+$X" popups. It only reads values
	the server replicates (leaderstats + player attributes).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local HudController = {}

local function makePill(parent, order, color)
	local pill = UIKit.create("Frame", {
		Size = UDim2.fromOffset(104, 30),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.corner(15), UIKit.stroke(color, 2) })
	return UIKit.label({
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		Font = Theme.Title,
		TextColor3 = color,
		MaxTextSize = 20,
		Parent = pill,
	})
end

function HudController:Start(controllers)
	local root = UIKit.root()

	local top = UIKit.create("Frame", {
		Name = "Hud",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(460, 100),
		BackgroundTransparency = 1,
		Parent = root,
	})

	local cashFrame = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(300, 58),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		Parent = top,
	}, { UIKit.corner(29), UIKit.stroke(Theme.Cyan, 3), UIKit.gradient(Color3.fromRGB(30, 60, 110), Color3.fromRGB(14, 18, 32)) })
	cashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	cashFrame.BackgroundTransparency = 0

	local cashLabel = UIKit.label({
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		Font = Theme.Title,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		MaxTextSize = 44,
		Text = "💵 $0",
		Parent = cashFrame,
	})

	local row = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	UIKit.label({
		Name = "Version",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.fromOffset(80, 18),
		TextColor3 = Theme.SubText,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 14,
		Text = require(ReplicatedStorage.Shared.Version),
		Parent = root,
	})

	local multiplierLabel = makePill(row, 1, Theme.Accent)
	local rebirthLabel = makePill(row, 2, Theme.Purple)
	local robotsLabel = makePill(row, 3, Theme.Blue)
	local prototypeLabel = makePill(row, 4, Color3.fromRGB(255, 120, 255))
	local premiumLabel = makePill(row, 5, Color3.fromRGB(255, 220, 80))
	premiumLabel.Text = "⭐ Premium"
	premiumLabel.Parent.Visible = player.MembershipType == Enum.MembershipType.Premium

	-- Wait for the server to finish loading this player
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local rebirths = leaderstats:WaitForChild("Rebirths")

	-- Cash counts up smoothly toward the real value
	local shown = cash.Value
	RunService.RenderStepped:Connect(function(dt)
		local target = cash.Value
		if math.abs(target - shown) < 1 then
			shown = target
		else
			shown += (target - shown) * math.min(1, dt * 10)
		end
		cashLabel.Text = "💵 " .. Format.cash(shown)
	end)

	local function updateStats()
		multiplierLabel.Text = "x" .. tostring(player:GetAttribute("CashMultiplier") or 1) .. " cash"
		rebirthLabel.Text = "🔄 " .. rebirths.Value
		robotsLabel.Text = "🤖 " .. Format.abbreviate(player:GetAttribute("Robots") or 0)
		local prototypes = player:GetAttribute("Prototypes") or 0
		prototypeLabel.Text = "⭐ " .. prototypes
		prototypeLabel.Parent.Visible = prototypes > 0
	end
	for _, attribute in ipairs({ "CashMultiplier", "Robots", "Prototypes" }) do
		player:GetAttributeChangedSignal(attribute):Connect(updateStats)
	end
	rebirths.Changed:Connect(updateStats)
	updateStats()

	-- "+$X" popups when cash is collected
	Net.On("CashPopup", function(amount)
		local popup = UIKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.random(-60, 60), 0, 40),
			Size = UDim2.fromOffset(220, 40),
			Font = Theme.Title,
			Text = "+" .. Format.cash(tonumber(amount) or 0),
			TextColor3 = Color3.fromRGB(120, 255, 140),
			TextStrokeTransparency = 0.3,
			MaxTextSize = 36,
			ZIndex = 5,
			Parent = top,
		})
		local tween = TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = popup.Position + UDim2.fromOffset(0, 90),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			popup:Destroy()
		end)
		local pop = TweenService:Create(cashFrame, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(140, 255, 170) })
		pop:Play()
		pop.Completed:Connect(function()
			TweenService:Create(cashFrame, TweenInfo.new(0.3), { BackgroundColor3 = Color3.new(1, 1, 1) }):Play()
		end)
	end)

	controllers.NotificationController:Show(
		"Welcome to Robot Factory Tycoon! Step on the green buttons to build your factory.",
		"info"
	)
end

return HudController
