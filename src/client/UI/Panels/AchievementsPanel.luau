--[[
	AchievementsPanel
	Every achievement, whether it's unlocked, and its title. Click an
	unlocked title to wear it (CosmeticAction "Title").
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AchievementConfig"))
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local AchievementsPanel = {}

function AchievementsPanel.build()
	local window, content = UIKit.window("🏅 ACHIEVEMENTS & TITLES", Theme.Accent, Vector2.new(640, 520))
	local header = UIKit.label({ Size = UDim2.new(1, 0, 0, 26), Font = Theme.Title, MaxTextSize = 22, Parent = content })
	UIKit.label({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), Text = "Unlocked titles can be worn over your head and in chat.", TextColor3 = Theme.SubText, MaxTextSize = 14, Parent = content })

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(296, 78), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local cards = {}
	for index, achievement in ipairs(AchievementConfig.Achievements) do
		local card = UIKit.card({ LayoutOrder = index, Parent = list }, Theme.PanelLight)
		local name = UIKit.label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 16), Text = achievement.Description, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 13, Parent = card })
		local wear = UIKit.button({
			Position = UDim2.new(0, 10, 1, -28),
			Size = UDim2.new(1, -20, 0, 22),
			Color = Theme.Accent,
			Text = achievement.Title,
			Parent = card,
		}, function()
			local current = player:GetAttribute("Title")
			Net.Fire("CosmeticAction", "Title", if current == achievement.Title then "" else achievement.Title)
		end)
		cards[achievement.Id] = { Card = card, Name = name, Wear = wear, Achievement = achievement }
	end

	local function update()
		local ok, unlocked = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("AchievementsJson") or "{}")
		unlocked = ok and type(unlocked) == "table" and unlocked or {}
		local count = 0
		local title = player:GetAttribute("Title") or ""
		for id, entry in pairs(cards) do
			local has = unlocked[id] == true
			if has then
				count += 1
			end
			entry.Name.Text = (if has then "✅ " else "🔒 ") .. entry.Achievement.Name
			entry.Card:FindFirstChildOfClass("UIStroke").Color = if has then Theme.Accent else Theme.PanelLight
			entry.Wear:SetAttribute("Disabled", not has)
			entry.Wear.Text = (if title == entry.Achievement.Title then "WEARING: " else "") .. entry.Achievement.Title
		end
		header.Text = ("%d / %d UNLOCKED"):format(count, #AchievementConfig.Achievements)
	end
	player:GetAttributeChangedSignal("AchievementsJson"):Connect(update)
	player:GetAttributeChangedSignal("Title"):Connect(update)
	update()
	return window
end

return AchievementsPanel
