--[[
	RaidController
	Top-of-screen bar while a boss raid is on (health + timer), and a small
	timer for your active contract.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Sfx = require(script.Parent.Parent.Sfx)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local RaidController = {}

function RaidController:Start()
	local root = UIKit.root()
	local bossBar = UIKit.card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(300, 64),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = root,
	}, Theme.Red)
	local bossTitle = UIKit.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Font = Theme.Title, Text = "☠️ BOSS RAID: LOBBY", TextColor3 = Theme.Red, MaxTextSize = 18, Parent = bossBar })
	local healthBar, setHealth = UIKit.progressBar({ Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 24), Parent = bossBar }, Theme.Red)
	local countdown = UIKit.label({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 30), Font = Theme.Title, TextColor3 = Theme.Accent, MaxTextSize = 28, Parent = bossBar })
	local lastTick = 0

	local contract = UIKit.card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 132),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = root,
	}, Color3.fromRGB(200, 150, 80))
	local contractText = UIKit.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = contract })
	local contractInfo = UIKit.label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.SubText, MaxTextSize = 14, Parent = contract })

	local activeContract
	local function readContract()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("ContractJson") or "{}")
		activeContract = ok and type(decoded) == "table" and decoded.Active or nil
	end
	player:GetAttributeChangedSignal("ContractJson"):Connect(readContract)
	readContract()

	RunService.Heartbeat:Connect(function()
		local active = workspace:GetAttribute("BossActive") == true
		local incoming = math.max(0, (workspace:GetAttribute("BossIncomingAt") or 0) - workspace:GetServerTimeNow())
		bossBar.Visible = active or incoming > 0
		healthBar.Visible = active
		countdown.Visible = not active
		if not active and incoming > 0 then
			bossTitle.Text = "☠️ BOSS INCOMING: LOBBY"
			countdown.Text = ("LANDS IN %d:%02d"):format(incoming // 60, math.floor(incoming % 60))
			-- Tick for the last 10 seconds
			local whole = math.ceil(incoming)
			if whole <= 10 and whole ~= lastTick then
				lastTick = whole
				Sfx.play("Tick")
			end
		end
		if active then
			bossTitle.Text = "☠️ BOSS RAID: LOBBY"
			local health = workspace:GetAttribute("BossHealth") or 0
			local max = math.max(1, workspace:GetAttribute("BossMaxHealth") or 1)
			local remaining = math.max(0, (workspace:GetAttribute("BossEndsAt") or 0) - workspace:GetServerTimeNow())
			setHealth(health / max, ("%d / %d  •  %ds left"):format(health, max, math.ceil(remaining)))
		end

		contract.Visible = activeContract ~= nil
		if activeContract then
			local remaining = math.max(0, activeContract.EndsAt - workspace:GetServerTimeNow())
			contractText.Text = "📜 " .. activeContract.Text
			contractInfo.Text = ("%d / %d   •   ⏱ %d:%02d"):format(activeContract.Progress, activeContract.Goal, remaining // 60, math.floor(remaining % 60))
		end
	end)
end

return RaidController
