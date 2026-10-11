--[[
	MinePanel
	Your ore, crafting Machine Cores, and selling ore.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MiningConfig"))
local Format = require(ReplicatedStorage.Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local MinePanel = {}

function MinePanel.build()
	local window, content = UIKit.window("⛏️ CRYSTAL MINE", Theme.Purple, Vector2.new(560, 440))
	UIKit.label({ Size = UDim2.new(1, 0, 0, 36), Text = "Go through the ⛏️ portal in the lobby and hold E on glowing ore to mine it.", TextColor3 = Theme.SubText, TextWrapped = true, MaxTextSize = 15, Parent = content })

	local rows = {}
	for index, ore in ipairs(MiningConfig.Ores) do
		local card = UIKit.card({ Position = UDim2.fromOffset(0, 40 + (index - 1) * 62), Size = UDim2.new(1, 0, 0, 54), Parent = content }, ore.Color)
		local label = UIKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -300, 1, -12), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ore.Color, MaxTextSize = 22, Parent = card })
		for i, amount in ipairs({ 1, 10 }) do
			UIKit.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10 - (2 - i) * 140, 0.5, 0),
				Size = UDim2.fromOffset(130, 38),
				Color = Theme.Green,
				Text = ("SELL %d • %s"):format(amount, Format.cash(MiningConfig.SellPrices[ore.Id] * amount)),
				Parent = card,
			}, function()
				Net.Fire("MineAction", "Sell", ore.Id, amount)
			end)
		end
		rows[ore.Id] = { Label = label, Ore = ore }
	end

	local craftCard = UIKit.card({ Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 0, 108), Parent = content }, Theme.Cyan)
	local cores = UIKit.label({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28), Font = Theme.Title, MaxTextSize = 22, Parent = craftCard })
	local recipe = {}
	for id, amount in pairs(MiningConfig.CoreRecipe) do
		table.insert(recipe, amount .. " " .. id)
	end
	table.sort(recipe)
	UIKit.label({ Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 18), Text = "Recipe: " .. table.concat(recipe, " + "), TextColor3 = Theme.SubText, MaxTextSize = 14, Parent = craftCard })
	local craft = UIKit.button({ Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 38), Color = Theme.Cyan, Text = "⚙️ CRAFT MACHINE CORE", Parent = craftCard }, function()
		Net.Fire("MineAction", "Craft")
	end)

	local function update()
		local canCraft = true
		for id, row in pairs(rows) do
			local amount = player:GetAttribute("Ore_" .. id) or 0
			row.Label.Text = ("%s: %d"):format(row.Ore.Name, amount)
			if amount < (MiningConfig.CoreRecipe[id] or 0) then
				canCraft = false
			end
		end
		local count = player:GetAttribute("Cores") or 0
		cores.Text = ("⚙️ MACHINE CORES: %d / %d  (+%d%% machine value)"):format(count, MiningConfig.MaxCores, count * MiningConfig.CoreBonus * 100)
		craft:SetAttribute("Disabled", not canCraft or count >= MiningConfig.MaxCores)
	end
	for _, ore in ipairs(MiningConfig.Ores) do
		player:GetAttributeChangedSignal("Ore_" .. ore.Id):Connect(update)
	end
	player:GetAttributeChangedSignal("Cores"):Connect(update)
	update()
	return window
end

return MinePanel
