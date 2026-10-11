--[[
	PetsPanel
	Buy eggs, hatch drone pets, and equip up to 3. Equipped pets follow you
	and boost your cash. Hatching plays a short egg animation.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared.Config.PetConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)
local Sfx = require(script.Parent.Parent.Parent.Sfx)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local PetsPanel = {}

local function chancesText(egg)
	local total = 0
	for _, entry in ipairs(egg.Pets) do
		total += entry.Weight
	end
	local parts = {}
	for _, entry in ipairs(egg.Pets) do
		table.insert(parts, ("%s %g%%"):format(PetConfig.Pets[entry.Pet].DisplayName, math.floor(entry.Weight / total * 1000) / 10))
	end
	return table.concat(parts, " • ")
end

-- Full-screen egg hatch animation
local function playHatch(petType, eggId)
	local info = PetConfig.Pets[petType]
	if not info then
		return
	end
	local eggIcon = "🥚"
	for _, egg in ipairs(PetConfig.Eggs) do
		if egg.Id == eggId then
			eggIcon = egg.Icon
		end
	end
	local overlay = UIKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 80,
		Parent = UIKit.root(),
	})
	local egg = UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(180, 180),
		Text = eggIcon,
		MaxTextSize = 150,
		ZIndex = 81,
		Parent = overlay,
	})
	for i = 1, 8 do
		egg.Rotation = if i % 2 == 0 then 14 else -14
		Sfx.play("Click")
		task.wait(0.12)
	end
	egg.Rotation = 0
	Sfx.play("Rebirth")
	local color = PetConfig.RarityColors[info.Rarity] or Theme.Text
	egg.Text = "🛸"
	egg.TextColor3 = color
	UIKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(500, 80),
		Font = Theme.Title,
		Text = ("%s\n%s  •  +%d%% cash"):format(string.upper(info.DisplayName), string.upper(info.Rarity), info.Bonus * 100),
		TextColor3 = color,
		TextStrokeTransparency = 0,
		MaxTextSize = 40,
		ZIndex = 81,
		Parent = overlay,
	})
	local scale = UIKit.create("UIScale", { Scale = 0.3, Parent = egg })
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.wait(2.2)
	overlay:Destroy()
end

function PetsPanel.build()
	local window, content = UIKit.window("🛸 PETS", Theme.Purple, Vector2.new(780, 540))

	-- Eggs
	local eggRow = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }) })
	-- Seasonal eggs only show while their season is on
	local season = workspace:GetAttribute("Season") or ""
	local eggs = {}
	for _, egg in ipairs(PetConfig.Eggs) do
		if not egg.Season or egg.Season == season then
			table.insert(eggs, egg)
		end
	end
	for _, egg in ipairs(eggs) do
		local card = UIKit.card({ Size = UDim2.new(1 / #eggs, -7, 1, 0), Parent = eggRow }, egg.Color)
		UIKit.label({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(60, 60), Text = egg.Icon, MaxTextSize = 50, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -82, 0, 26), Font = Theme.Title, Text = string.upper(egg.DisplayName), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(74, 34), Size = UDim2.new(1, -82, 0, 34), Text = chancesText(egg), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.SubText, MaxTextSize = 12, Parent = card })
		UIKit.button({
			Position = UDim2.new(0, 8, 1, -46),
			Size = UDim2.new(1, -16, 0, 38),
			Color = Theme.Purple,
			Text = "HATCH  " .. Format.cash(egg.Price),
			Parent = card,
		}, function()
			Net.Fire("HatchEgg", egg.Id)
		end)
	end

	local status = UIKit.label({ Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 24), Font = Theme.Title, MaxTextSize = 20, Parent = content })

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 1, -158),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(142, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function update()
		local ok, pets = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PetsJson") or "[]")
		pets = ok and pets or {}
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local equipped, bonus = 0, 0
		for order, pet in ipairs(pets) do
			local info = PetConfig.Pets[pet.Type]
			if info then
				if pet.Equipped then
					equipped += 1
					bonus += info.Bonus
				end
				local color = PetConfig.RarityColors[info.Rarity] or Theme.Text
				local card = UIKit.card({ LayoutOrder = if pet.Equipped then order else 1000 + order, Parent = list }, if pet.Equipped then Theme.Green else color)
				UIKit.label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), Text = "🛸", TextColor3 = info.Color, MaxTextSize = 36, Parent = card })
				UIKit.label({ Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 22), Font = Theme.Title, Text = info.DisplayName, TextColor3 = color, MaxTextSize = 18, Parent = card })
				UIKit.label({ Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 16), Text = ("%s • +%d%%"):format(info.Rarity, info.Bonus * 100), TextColor3 = Theme.SubText, MaxTextSize = 13, Parent = card })
				UIKit.button({
					Position = UDim2.fromOffset(6, 88),
					Size = UDim2.new(1, -12, 0, 28),
					Color = if pet.Equipped then Theme.Disabled else Theme.Green,
					Text = if pet.Equipped then "UNEQUIP" else "EQUIP",
					Parent = card,
				}, function()
					Net.Fire("PetAction", if pet.Equipped then "Unequip" else "Equip", pet.Id)
				end)
				UIKit.button({
					Position = UDim2.fromOffset(6, 120),
					Size = UDim2.new(1, -12, 0, 24),
					Color = Theme.Red,
					Text = "DELETE",
					Parent = card,
				}, function()
					UIKit.confirm("Delete pet?", ("Delete %s (%s)? This can't be undone."):format(info.DisplayName, info.Rarity), "Delete", function()
						Net.Fire("PetAction", "Delete", pet.Id)
					end)
				end)
			end
		end
		status.Text = ("EQUIPPED %d / %d  •  +%d%% CASH  •  %d / %d PETS"):format(equipped, PetConfig.MaxEquipped, math.floor(bonus * 100 + 0.5), #pets, PetConfig.MaxInventory)
	end
	player:GetAttributeChangedSignal("PetsJson"):Connect(update)
	update()

	Net.On("PetHatched", function(petType, eggId)
		task.spawn(playHatch, petType, eggId)
	end)

	return window
end

return PetsPanel
