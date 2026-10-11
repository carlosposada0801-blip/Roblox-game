--[[
	RacePanel
	Enter the next robot race and upgrade your race bot with robots.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RaceConfig"))
local Format = require(ReplicatedStorage.Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local RacePanel = {}

function RacePanel.build()
	local window, content = UIKit.window("🏁 ROBOT RACES", Theme.Accent, Vector2.new(520, 400))
	UIKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		Text = ("Enter your race bot. It races itself! Prizes: %s / %s / %s (x rebirths). Watch from the 🏁 portal in the lobby."):format(Format.cash(RaceConfig.Prizes[1]), Format.cash(RaceConfig.Prizes[2]), Format.cash(RaceConfig.Prizes[3])),
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		MaxTextSize = 15,
		Parent = content,
	})
	local status = UIKit.label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 30), Font = Theme.Title, MaxTextSize = 24, Parent = content })
	local entrants = UIKit.label({ Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 20), TextColor3 = Theme.SubText, MaxTextSize = 15, Parent = content })
	UIKit.button({ Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 56), Color = Theme.Accent, Text = "🏁 ENTER NEXT RACE", Parent = content }, function()
		Net.Fire("RaceAction", "Join")
	end)

	local botCard = UIKit.card({ Position = UDim2.fromOffset(0, 180), Size = UDim2.new(1, 0, 0, 110), Parent = content }, Theme.Cyan)
	local level = UIKit.label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), Font = Theme.Title, MaxTextSize = 24, Parent = botCard })
	local upgrade = UIKit.button({ Position = UDim2.new(0, 12, 1, -58), Size = UDim2.new(1, -24, 0, 46), Color = Theme.Cyan, Parent = botCard }, function()
		Net.Fire("RaceAction", "Upgrade")
	end)

	local function update()
		local botLevel = player:GetAttribute("RaceBotLevel") or 1
		local speed = RaceConfig.BaseSpeed + (botLevel - 1) * RaceConfig.SpeedPerLevel
		level.Text = ("🤖 RACE BOT  Lv %d  •  speed %d"):format(botLevel, speed)
		if botLevel >= RaceConfig.MaxLevel then
			upgrade.Text = "MAX LEVEL"
			upgrade:SetAttribute("Disabled", true)
		else
			local cost = RaceConfig.UpgradeCost(botLevel)
			upgrade.Text = ("UPGRADE  •  %d 🤖"):format(cost)
			upgrade:SetAttribute("Disabled", (player:GetAttribute("Robots") or 0) < cost)
		end
		local names = workspace:GetAttribute("RaceEntrants") or ""
		entrants.Text = if names ~= "" then "Entered: " .. names else "No one has entered yet"
	end
	player:GetAttributeChangedSignal("RaceBotLevel"):Connect(update)
	player:GetAttributeChangedSignal("Robots"):Connect(update)
	workspace:GetAttributeChangedSignal("RaceEntrants"):Connect(update)
	update()

	RunService.Heartbeat:Connect(function()
		if not window.Visible then
			return
		end
		if workspace:GetAttribute("RaceState") == "Racing" then
			status.Text = "🏎️ RACE IN PROGRESS!"
		else
			local remaining = math.max(0, (workspace:GetAttribute("RaceStartsAt") or 0) - workspace:GetServerTimeNow())
			status.Text = ("Next race in %ds"):format(math.ceil(remaining))
		end
	end)
	return window
end

return RacePanel
