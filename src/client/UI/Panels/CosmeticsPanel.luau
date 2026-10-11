--[[
	CosmeticsPanel
	Trails and factory accent colors. Buy with cash or unlock with achievements.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local CosmeticsPanel = {}

local achievementNames = {}
for _, achievement in ipairs(AchievementConfig.Achievements) do
	achievementNames[achievement.Id] = achievement.Name
end

function CosmeticsPanel.build()
	local window, content = UIKit.window("✨ STYLE", Theme.Pink, Vector2.new(640, 500))
	local list = UIKit.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rows = {}
	local order = 0
	local function section(title)
		order += 1
		UIKit.label({ Size = UDim2.new(1, -10, 0, 30), Font = Theme.Title, Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Pink, MaxTextSize = 24, LayoutOrder = order, Parent = list })
	end
	local function addRow(item, kind)
		order += 1
		local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 58), LayoutOrder = order, Parent = list }, item.Color)
		UIKit.create("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = item.Color, Parent = card }, { UIKit.corner(17) })
		UIKit.label({ Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -240, 0, 24), Font = Theme.Title, Text = item.Name, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = card })
		local how = if item.Achievement then ("🏅 Achievement: " .. (achievementNames[item.Achievement] or item.Achievement)) else Format.cash(item.Price)
		UIKit.label({ Position = UDim2.fromOffset(58, 30), Size = UDim2.new(1, -240, 0, 18), Text = how, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = card })
		local button = UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 40),
			Parent = card,
		}, function()
			local owned = player:GetAttribute("Owns_" .. item.Id)
			local equipped = player:GetAttribute("Equipped" .. kind) == item.Id
			if not owned then
				Net.Fire("CosmeticAction", "Buy", item.Id)
			else
				Net.Fire("CosmeticAction", kind, if equipped then "" else item.Id)
			end
		end)
		rows[item.Id] = { Item = item, Kind = kind, Button = button }
	end

	section("🌠 TRAILS")
	for _, trail in ipairs(CosmeticConfig.Trails) do
		addRow(trail, "Trail")
	end
	section("🎨 FACTORY COLORS")
	for _, accent in ipairs(CosmeticConfig.Accents) do
		addRow(accent, "Accent")
	end

	local function update()
		for id, row in pairs(rows) do
			local owned = player:GetAttribute("Owns_" .. id) == true
			local equipped = player:GetAttribute("Equipped" .. row.Kind) == id
			if equipped then
				row.Button.Text = "EQUIPPED ✓"
				row.Button:SetAttribute("BaseColor", Theme.Green)
				row.Button:SetAttribute("Disabled", false)
			elseif owned then
				row.Button.Text = "EQUIP"
				row.Button:SetAttribute("BaseColor", Theme.Blue)
				row.Button:SetAttribute("Disabled", false)
			else
				row.Button.Text = if row.Item.Achievement then "LOCKED 🔒" else "BUY"
				row.Button:SetAttribute("BaseColor", Theme.Accent)
				row.Button:SetAttribute("Disabled", row.Item.Achievement ~= nil)
			end
		end
	end
	for id in pairs(rows) do
		player:GetAttributeChangedSignal("Owns_" .. id):Connect(update)
	end
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(update)
	player:GetAttributeChangedSignal("EquippedAccent"):Connect(update)
	update()
	return window
end

return CosmeticsPanel
