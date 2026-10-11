--[[
	ArenaController
	While you're in the PvP arena, shows Deploy/Recall Prototype and
	Leave Arena buttons. The server decides whether you may deploy.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local ArenaController = {}

function ArenaController:Start()
	local bar = UIKit.create("Frame", {
		Name = "ArenaBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100), -- above the tool hotbar
		Size = UDim2.fromOffset(460, 56),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = UIKit.root(),
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local deploy = UIKit.button({
		Size = UDim2.fromOffset(240, 56),
		Color = Theme.Purple,
		LayoutOrder = 1,
		Parent = bar,
	}, function()
		Net.Fire("ArenaAction", if player:GetAttribute("PrototypeDeployed") then "Recall" else "Deploy")
	end)

	UIKit.button({
		Size = UDim2.fromOffset(180, 56),
		Color = Theme.Red,
		Text = "🏠 Leave Arena",
		LayoutOrder = 2,
		Parent = bar,
	}, function()
		Net.Fire("ArenaAction", "Leave")
	end)

	-- Round info above the buttons
	local info = UIKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -162),
		Size = UDim2.fromOffset(520, 30),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Font = Theme.Title,
		MaxTextSize = 20,
		Visible = false,
		Parent = UIKit.root(),
	})
	UIKit.corner(10).Parent = info
	RunService.Heartbeat:Connect(function()
		if not info.Visible then
			return
		end
		local remaining = math.max(0, (workspace:GetAttribute("ArenaRoundEndsAt") or 0) - workspace:GetServerTimeNow())
		local leader = workspace:GetAttribute("ArenaLeader") or ""
		info.Text = ("⏱ %d:%02d   •   Your score: %d   •   %s"):format(
			remaining // 60,
			math.floor(remaining % 60),
			player:GetAttribute("ArenaScore") or 0,
			if leader ~= "" then "👑 " .. leader else "Stand on the glowing hill for points!"
		)
	end)

	local function update()
		bar.Visible = player:GetAttribute("InArena") == true
		info.Visible = bar.Visible
		local prototypes = player:GetAttribute("Prototypes") or 0
		deploy.Visible = prototypes > 0
		deploy.Text = if player:GetAttribute("PrototypeDeployed")
			then "Recall Prototype"
			else ("⭐ Deploy Prototype (%d)"):format(prototypes)
	end

	for _, attribute in ipairs({ "InArena", "Prototypes", "PrototypeDeployed" }) do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()
end

return ArenaController
