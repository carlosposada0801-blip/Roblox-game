--[[
	QuestsPanel
	Today's quests with progress bars. Finished quests can be claimed.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local QuestsPanel = {}

local function rewardText(reward)
	return Format.reward(reward)
end

function QuestsPanel.build()
	local window, content = UIKit.window("📋 DAILY QUESTS", Theme.Green, Vector2.new(560, 400))

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.SubText,
		MaxTextSize = 16,
		Text = "New quests every day. Cash rewards grow with rebirths!",
		Parent = content,
	})

	local list = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rows = {}
	for index = 1, 3 do
		local card = UIKit.card({ Size = UDim2.new(1, 0, 0, 92), LayoutOrder = index, Parent = list }, Theme.Green)
		local title = UIKit.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 26), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = card })
		local reward = UIKit.label({ Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -170, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 120), MaxTextSize = 16, Parent = card })
		local _, setProgress = UIKit.progressBar({ Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -170, 0, 20), Parent = card }, Theme.Green)
		local claim = UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(136, 50),
			Color = Theme.Green,
			Text = "CLAIM",
			Parent = card,
		}, function()
			Net.Fire("ClaimQuest", index)
		end)
		rows[index] = { Card = card, Title = title, Reward = reward, SetProgress = setProgress, Claim = claim }
	end

	local function update()
		local ok, quests = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("QuestsJson") or "[]")
		quests = ok and quests or {}
		for index, row in ipairs(rows) do
			local quest = quests[index]
			row.Card.Visible = quest ~= nil
			if quest then
				row.Title.Text = quest.Text
				row.Reward.Text = "Reward: " .. rewardText(quest.Reward or {})
				row.SetProgress(quest.Progress / quest.Goal, ("%s / %s"):format(Format.abbreviate(quest.Progress), Format.abbreviate(quest.Goal)))
				if quest.Claimed then
					row.Claim.Text = "DONE ✓"
					row.Claim:SetAttribute("Disabled", true)
				else
					row.Claim.Text = "CLAIM"
					row.Claim:SetAttribute("Disabled", quest.Progress < quest.Goal)
				end
			end
		end
	end
	player:GetAttributeChangedSignal("QuestsJson"):Connect(update)
	update()

	return window
end

return QuestsPanel
