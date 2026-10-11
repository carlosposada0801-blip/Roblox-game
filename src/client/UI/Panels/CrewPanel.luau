--[[
	CrewPanel
	Create or join a crew, donate to its bank, and (owner) level it up.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrewConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CrewConfig"))
local Format = require(ReplicatedStorage.Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local CrewPanel = {}

function CrewPanel.build()
	local window, content = UIKit.window("🛡️ CREW", Theme.Blue, Vector2.new(540, 430))

	-- Not in a crew
	local joinView = UIKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	UIKit.label({ Size = UDim2.new(1, 0, 0, 44), Text = ("Team up! Crew members donate cash to level the crew; every level gives all members +%d%% cash. Crews work across servers."):format(CrewConfig.BonusPerLevel * 100), TextWrapped = true, TextColor3 = Theme.SubText, MaxTextSize = 15, Parent = joinView })
	local nameBox = UIKit.create("TextBox", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Panel,
		Font = Theme.Title,
		PlaceholderText = "Crew name",
		Text = "",
		TextColor3 = Theme.Text,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = joinView,
	}, { UIKit.corner(10), UIKit.stroke(Theme.Blue, 2), UIKit.padding(8) })
	UIKit.button({ Position = UDim2.fromOffset(0, 112), Size = UDim2.new(0.5, -5, 0, 52), Color = Theme.Green, Text = "CREATE • " .. Format.cash(CrewConfig.CreateCost), Parent = joinView }, function()
		Net.Fire("CrewAction", "Create", nameBox.Text)
	end)
	UIKit.button({ Position = UDim2.new(0.5, 5, 0, 112), Size = UDim2.new(0.5, -5, 0, 52), Color = Theme.Blue, Text = "JOIN", Parent = joinView }, function()
		Net.Fire("CrewAction", "Join", nameBox.Text)
	end)

	-- In a crew
	local crewView = UIKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	local title = UIKit.label({ Size = UDim2.new(1, 0, 0, 36), Font = Theme.Title, MaxTextSize = 30, Parent = crewView })
	local stats = UIKit.label({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 48), TextWrapped = true, MaxTextSize = 17, Parent = crewView })
	for i, amount in ipairs({ 10000, 100000, 1000000 }) do
		UIKit.button({ Position = UDim2.new((i - 1) / 3, 3, 0, 98), Size = UDim2.new(1 / 3, -6, 0, 46), Color = Theme.Green, Text = "DONATE " .. Format.cash(amount), Parent = crewView }, function()
			Net.Fire("CrewAction", "Donate", amount)
		end)
	end
	local upgrade = UIKit.button({ Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 52), Color = Theme.Accent, Parent = crewView }, function()
		Net.Fire("CrewAction", "Upgrade")
	end)
	UIKit.button({ Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 40), Color = Theme.Red, Text = "LEAVE CREW", Parent = crewView }, function()
		UIKit.confirm("Leave crew?", "You'll lose the crew cash bonus. You can join again later.", "Leave", function()
			Net.Fire("CrewAction", "Leave")
		end)
	end)

	local function update()
		local name = player:GetAttribute("CrewName") or ""
		joinView.Visible = name == ""
		crewView.Visible = name ~= ""
		if name ~= "" then
			local level = player:GetAttribute("CrewLevel") or 1
			title.Text = "🛡️ " .. string.upper(name)
			stats.Text = ("Level %d  •  +%d%% cash  •  %d members  •  Bank %s"):format(level, (level - 1) * CrewConfig.BonusPerLevel * 100, player:GetAttribute("CrewMembers") or 1, Format.cash(player:GetAttribute("CrewBank") or 0))
			local isOwner = player:GetAttribute("CrewOwner") == true
			if level >= CrewConfig.MaxLevel then
				upgrade.Text = "MAX LEVEL"
				upgrade:SetAttribute("Disabled", true)
			else
				local cost = CrewConfig.LevelCost(level)
				upgrade.Text = if isOwner then ("LEVEL UP • %s from bank"):format(Format.cash(cost)) else ("Owner can level up at %s"):format(Format.cash(cost))
				upgrade:SetAttribute("Disabled", not isOwner or (player:GetAttribute("CrewBank") or 0) < cost)
			end
		end
	end
	for _, attribute in ipairs({ "CrewName", "CrewLevel", "CrewBank", "CrewOwner", "CrewMembers" }) do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()
	return window
end

return CrewPanel
