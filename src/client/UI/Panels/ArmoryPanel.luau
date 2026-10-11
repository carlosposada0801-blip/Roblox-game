--[[
	ArmoryPanel
	Unlock weapons with cash (kept forever) and switch PvP on/off.
	Weapons appear in your hotbar in the arena, or anywhere while PvP is on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local ArmoryPanel = {}

local function statsText(weapon)
	local parts = { ("💥 %d dmg"):format(weapon.Damage) }
	if weapon.Type == "Melee" then
		table.insert(parts, ("📏 %d studs"):format(weapon.Range))
	elseif weapon.Type == "Rocket" then
		table.insert(parts, ("💣 %d radius"):format(weapon.Radius))
	else
		table.insert(parts, ("🎯 %d range"):format(weapon.Range))
	end
	table.insert(parts, ("⏱ %gs"):format(weapon.Cooldown))
	return table.concat(parts, "   ")
end

function ArmoryPanel.build()
	local window, content = UIKit.window("⚔️ ARMORY", Theme.Red, Vector2.new(620, 520))

	-- PvP switch
	local pvpCard = UIKit.card({ Size = UDim2.new(1, 0, 0, 70) , Parent = content }, Theme.Red)
	local pvpText = UIKit.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -190, 1, -16),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = pvpCard,
	})
	local pvpButton = UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(160, 48),
		Parent = pvpCard,
	}, function()
		Net.Fire("SetPvP", not player:GetAttribute("PvP"))
	end)

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rows = {}
	for index, weapon in ipairs(WeaponConfig.Weapons) do
		local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 78), LayoutOrder = index, Parent = list }, weapon.Color)
		UIKit.label({ Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(60, 60), Text = weapon.Icon, MaxTextSize = 42, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(76, 6), Size = UDim2.new(1, -250, 0, 26), Font = Theme.Title, Text = string.upper(weapon.DisplayName), TextColor3 = weapon.Color, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(76, 32), Size = UDim2.new(1, -250, 0, 18), Text = weapon.Description, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(76, 52), Size = UDim2.new(1, -250, 0, 18), Text = statsText(weapon), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = card })
		local buy = UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(150, 48),
			Color = Theme.Green,
			Parent = card,
		}, function()
			Net.Fire("BuyWeapon", weapon.Id)
		end)
		rows[weapon.Id] = { Weapon = weapon, Button = buy }
	end

	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local function update()
		local on = player:GetAttribute("PvP") == true
		pvpButton.Text = if on then "⚔️ PVP: ON" else "🛡️ PVP: OFF"
		pvpButton:SetAttribute("BaseColor", if on then Theme.Red else Theme.Disabled)
		pvpText.Text = if on
			then "PvP is ON: you and other PvP players can fight anywhere. Your weapons are in your hotbar."
			else "PvP is OFF: nobody can hurt you outside the arena. Turn it on to fight other PvP players anywhere."

		for _, row in pairs(rows) do
			local weapon = row.Weapon
			local owned
			if weapon.RequiresPrototype then
				owned = (player:GetAttribute("Prototypes") or 0) > 0
				row.Button.Text = if owned then "OWNED ✓" else "NEED ⭐"
				row.Button:SetAttribute("Disabled", true)
			else
				owned = player:GetAttribute("Weapon_" .. weapon.Id) == true
				row.Button.Text = if owned then "OWNED ✓" else Format.cash(weapon.Price)
				row.Button:SetAttribute("Disabled", owned or cash.Value < weapon.Price)
			end
		end
	end
	for _, weapon in ipairs(WeaponConfig.Weapons) do
		player:GetAttributeChangedSignal("Weapon_" .. weapon.Id):Connect(update)
	end
	player:GetAttributeChangedSignal("PvP"):Connect(update)
	player:GetAttributeChangedSignal("Prototypes"):Connect(update)
	cash.Changed:Connect(update)
	update()

	return window
end

return ArmoryPanel
