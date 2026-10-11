--[[
	DailyPanel
	A 7-day reward calendar. Today's reward glows; Claim sends ClaimDaily.
	Opens by itself when you join with a reward waiting (DailyController).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyConfig = require(Shared.Config.DailyConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local DailyPanel = {}

local function rewardText(reward)
	return Format.reward(reward, "\n")
end

function DailyPanel.build()
	local window, content = UIKit.window("🎁 DAILY REWARDS", Theme.Pink, Vector2.new(640, 380))

	local streakLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 30), Font = Theme.Title, MaxTextSize = 26, Parent = content })
	UIKit.label({
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Theme.SubText,
		MaxTextSize = 15,
		Text = "Come back every day to build your streak. Missing a day resets it. Cash grows with rebirths!",
		Parent = content,
	})

	local row = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local cards = {}
	for day, reward in ipairs(DailyConfig.Rewards) do
		local card = UIKit.card({ Size = UDim2.fromOffset(80, 140), LayoutOrder = day, Parent = row }, Theme.PanelLight)
		UIKit.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 6), Font = Theme.Title, Text = "DAY " .. day, MaxTextSize = 18, Parent = card })
		UIKit.label({
			Position = UDim2.fromOffset(4, 38),
			Size = UDim2.new(1, -8, 0, 70),
			Text = rewardText(reward),
			TextWrapped = true,
			MaxTextSize = 16,
			Font = Theme.Title,
			TextColor3 = Color3.fromRGB(255, 230, 140),
			Parent = card,
		})
		local check = UIKit.label({ Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 24), Text = "", MaxTextSize = 20, Parent = card })
		cards[day] = { Card = card, Check = check }
	end

	local claim = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.5, 0, 0, 54),
		Color = Theme.Pink,
		Text = "CLAIM",
		Parent = content,
	}, function()
		Net.Fire("ClaimDaily")
	end)

	local function update()
		local available = player:GetAttribute("DailyAvailable") == true
		local streak = player:GetAttribute("DailyStreak") or 1
		local index = player:GetAttribute("DailyIndex") or 1
		streakLabel.Text = ("🔥 STREAK: %d DAY%s"):format(streak, streak == 1 and "" or "S")
		for day, entry in pairs(cards) do
			local stroke = entry.Card:FindFirstChildOfClass("UIStroke")
			if day < index or (day == index and not available) then
				entry.Check.Text = "✅"
				stroke.Color = Theme.Green
			elseif day == index then
				entry.Check.Text = "TODAY"
				stroke.Color = Theme.Pink
				stroke.Thickness = 4
			else
				entry.Check.Text = ""
				stroke.Color = Theme.PanelLight
				stroke.Thickness = 2
			end
		end
		claim:SetAttribute("Disabled", not available)
		claim.Text = if available then "CLAIM" else "COME BACK TOMORROW"
	end
	for _, attribute in ipairs({ "DailyAvailable", "DailyStreak", "DailyIndex" }) do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()

	return window
end

return DailyPanel
