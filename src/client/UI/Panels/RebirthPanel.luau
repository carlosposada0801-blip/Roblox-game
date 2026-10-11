--[[
	RebirthPanel
	Shows the next rebirth's cost and reward with a progress bar. The button
	opens a confirmation dialog; only then is RequestRebirth sent. The server
	re-checks the cost.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local RebirthPanel = {}

function RebirthPanel.build()
	local window, content = UIKit.window("🔄 Rebirth", Theme.Purple, Vector2.new(520, 500))

	local levelLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 44), Font = Theme.Title, MaxTextSize = 40, Parent = content })
	local multiplierLabel = UIKit.label({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.Title,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		MaxTextSize = 30,
		Parent = content,
	})
	UIKit.label({
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 64),
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		MaxTextSize = 18,
		Text = "Reset your cash and factory for a permanent cash boost.\nYou keep robots, Prototypes, workers, pets, passes, skins, badges, your yard and the Sky Factory.",
		Parent = content,
	})

	local costLabel = UIKit.label({ Position = UDim2.fromOffset(0, 164), Size = UDim2.new(1, 0, 0, 28), Font = Theme.Title, MaxTextSize = 24, Parent = content })

	local bar = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.PanelLight,
		ClipsDescendants = true,
		Parent = content,
	}, { UIKit.corner(15) })
	local fill = UIKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Purple, Parent = bar }, { UIKit.corner(15) })
	local barText = UIKit.label({ Size = UDim2.fromScale(1, 1), Font = Theme.Title, MaxTextSize = 18, ZIndex = 2, Parent = bar })

	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local rebirths = leaderstats:WaitForChild("Rebirths")

	local rebirthButton
	rebirthButton = UIKit.button({
		Text = "REBIRTH",
		Color = Theme.Purple,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.new(0.6, 0, 0, 56),
		Parent = content,
	}, function()
		local cost = RebirthConfig.GetCost(rebirths.Value)
		local nextMultiplier = RebirthConfig.GetMultiplier(rebirths.Value + 1)
		UIKit.confirm(
			"Rebirth?",
			("❌ LOSE: %s cash, factory items, upgrades\n✅ KEEP: robots, Prototypes, workers, pets, game passes, skins, badges, yard, Sky Factory\n⭐ GAIN: x%s cash forever!"):format(Format.cash(cash.Value), tostring(nextMultiplier)),
			"Rebirth!",
			function()
				if cash.Value >= cost then
					Net.Fire("RequestRebirth")
				end
			end
		)
	end)

	local function update()
		local current = rebirths.Value
		local cost = RebirthConfig.GetCost(current)
		levelLabel.Text = ("Rebirth %d  ➜  %d"):format(current, current + 1)
		multiplierLabel.Text = ("Cash x%s  ➜  x%s"):format(
			tostring(RebirthConfig.GetMultiplier(current)),
			tostring(RebirthConfig.GetMultiplier(current + 1))
		)
		costLabel.Text = "Cost: " .. Format.cash(cost)

		local progress = math.clamp(cash.Value / cost, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		barText.Text = ("%s / %s"):format(Format.cash(cash.Value), Format.cash(cost))

		local ready = cash.Value >= cost
		rebirthButton:SetAttribute("Disabled", not ready)
		rebirthButton.Text = if ready then "REBIRTH" else "NOT ENOUGH CASH"
	end

	cash.Changed:Connect(update)
	rebirths.Changed:Connect(update)
	update()

	-- Ascension (prestige)
	local ascend = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 52),
		Color = Color3.fromRGB(255, 200, 40),
		Parent = content,
	}, function()
		local ascensions = player:GetAttribute("Ascensions") or 0
		local nextTheme = AscensionConfig.Themes[ascensions + 1]
		UIKit.confirm(
			"✨ Ascend?",
			("Resets your rebirths, cash and factory. You get x%d cash FOREVER%s."):format(
				AscensionConfig.MultiplierPerAscension ^ (ascensions + 1),
				if nextTheme then " and the " .. nextTheme.Name .. " theme" else ""
			),
			"ASCEND!",
			function()
				Net.Fire("Ascend")
			end
		)
	end)
	local function updateAscend()
		local ascensions = player:GetAttribute("Ascensions") or 0
		local ready = rebirths.Value >= AscensionConfig.RequiredRebirths
		ascend.Text = if ready
			then ("✨ ASCEND (level %d → %d)"):format(ascensions, ascensions + 1)
			else ("✨ ASCEND at %d rebirths (level %d)"):format(AscensionConfig.RequiredRebirths, ascensions)
		ascend:SetAttribute("Disabled", not ready)
	end
	rebirths.Changed:Connect(updateAscend)
	player:GetAttributeChangedSignal("Ascensions"):Connect(updateAscend)
	updateAscend()

	return window
end

return RebirthPanel
