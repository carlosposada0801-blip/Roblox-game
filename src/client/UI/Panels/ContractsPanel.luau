--[[
	ContractsPanel
	Pick a timed contract; shows the active one with a countdown.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local ContractsPanel = {}

local function rewardText(reward)
	local parts = {}
	if reward.Cash then
		table.insert(parts, "💵 " .. Format.cash(reward.Cash) .. "+")
	end
	if reward.Robots then
		table.insert(parts, "🤖 " .. reward.Robots)
	end
	return table.concat(parts, "  ")
end

function ContractsPanel.build()
	local window, content = UIKit.window("📜 CONTRACTS", Color3.fromRGB(200, 150, 80), Vector2.new(580, 460))
	UIKit.label({ Size = UDim2.new(1, 0, 0, 20), Text = "Finish a job before the timer runs out for a big reward. Rewards grow with rebirths!", TextColor3 = Theme.SubText, TextWrapped = true, MaxTextSize = 14, Parent = content })

	-- Active contract
	local active = UIKit.card({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 100), Parent = content }, Theme.Accent)
	local activeTitle = UIKit.label({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -150, 0, 26), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = active })
	local activeTimer = UIKit.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(120, 26), Font = Theme.Title, TextColor3 = Theme.Accent, MaxTextSize = 22, Parent = active })
	local _, setProgress = UIKit.progressBar({ Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 22), Parent = active }, Theme.Accent)
	local abandon = UIKit.button({ Position = UDim2.new(1, -132, 1, -32), Size = UDim2.fromOffset(120, 26), Color = Theme.Red, Text = "ABANDON", Parent = active }, function()
		Net.Fire("ContractAction", "Abandon")
	end)

	local offers = {}
	for index = 1, 3 do
		local card = UIKit.card({ Position = UDim2.fromOffset(0, 136 + (index - 1) * 82), Size = UDim2.new(1, 0, 0, 74), Parent = content }, Theme.PanelLight)
		local text = UIKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 26), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
		local info = UIKit.label({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -170, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 120), MaxTextSize = 15, Parent = card })
		local accept = UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 46), Color = Theme.Green, Text = "ACCEPT", Parent = card }, function()
			Net.Fire("ContractAction", "Accept", index)
		end)
		offers[index] = { Card = card, Text = text, Info = info, Accept = accept }
	end

	local state: any = {}
	local function update()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("ContractJson") or "{}")
		state = ok and type(decoded) == "table" and decoded or {}
		local current = state.Active
		active.Visible = current ~= nil
		if current then
			activeTitle.Text = "ACTIVE: " .. current.Text
			setProgress(current.Progress / current.Goal, ("%s / %s  •  %s"):format(Format.abbreviate(current.Progress), Format.abbreviate(current.Goal), rewardText(current.Reward)))
		end
		for index, offer in ipairs(offers) do
			local data = state.Offers and state.Offers[index]
			offer.Card.Visible = data ~= nil
			if data then
				offer.Text.Text = data.Text
				offer.Info.Text = ("⏱ %d min  •  %s"):format(math.floor(data.Time / 60), rewardText(data.Reward))
				offer.Accept:SetAttribute("Disabled", current ~= nil)
			end
		end
	end
	player:GetAttributeChangedSignal("ContractJson"):Connect(update)
	update()

	RunService.Heartbeat:Connect(function()
		if not window.Visible then
			return
		end
		local now = workspace:GetServerTimeNow()
		if state.Active then
			local remaining = math.max(0, state.Active.EndsAt - now)
			activeTimer.Text = ("%d:%02d"):format(remaining // 60, math.floor(remaining % 60))
		end
		local cooldown = (state.CooldownUntil or 0) - now
		for _, offer in ipairs(offers) do
			if not state.Active then
				offer.Accept:SetAttribute("Disabled", cooldown > 0)
				offer.Accept.Text = if cooldown > 0 then ("WAIT %ds"):format(math.ceil(cooldown)) else "ACCEPT"
			end
		end
	end)
	abandon.Visible = true
	return window
end

return ContractsPanel
