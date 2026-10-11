--[[
	CustomizePanel
	Paint your walls and machines, pick a floor, put up a neon sign with your
	own text, and place decorations. The server (CustomizationService) checks
	prices, VIP status and filters sign text; this only sends CustomAction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomConfig = require(Shared.Config.CustomConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local CustomizePanel = {}

local function priceText(item)
	if item.VIP then
		return "⭐ VIP (Premium or VIP pass)"
	elseif (item.Price or 0) == 0 then
		return "FREE"
	end
	return Format.cash(item.Price)
end

function CustomizePanel.build()
	local window, content = UIKit.window("🎨 CUSTOMIZE", Theme.Pink, Vector2.new(660, 520))
	local list = UIKit.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local order = 0
	local updaters = {}
	local function nextOrder()
		order += 1
		return order
	end
	local function section(title)
		UIKit.label({ Size = UDim2.new(1, -10, 0, 30), Font = Theme.Title, Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Pink, MaxTextSize = 24, LayoutOrder = nextOrder(), Parent = list })
	end

	-- Neon sign
	section("🪧 NEON SIGN (over your gate)")
	local signRow = UIKit.card({ Size = UDim2.new(1, -10, 0, 60), LayoutOrder = nextOrder(), Parent = list })
	local signBox = UIKit.create("TextBox", {
		Name = "SignBox",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -150, 0, 40),
		BackgroundColor3 = Theme.PanelLight,
		Font = Theme.Title,
		PlaceholderText = "Your sign text (max " .. CustomConfig.SignMaxLength .. ")",
		PlaceholderColor3 = Theme.SubText,
		Text = player:GetAttribute("Custom_Sign") or "",
		TextColor3 = CustomConfig.SignColor,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = signRow,
	}, { UIKit.corner(8), UIKit.padding(6) })
	signBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #signBox.Text > CustomConfig.SignMaxLength then
			signBox.Text = string.sub(signBox.Text, 1, CustomConfig.SignMaxLength)
		end
	end)
	UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 40), Color = Theme.Pink, Text = "SET SIGN", Parent = signRow }, function()
		Net.Fire("CustomAction", "Sign", signBox.Text)
	end)
	player:GetAttributeChangedSignal("Custom_Sign"):Connect(function()
		signBox.Text = player:GetAttribute("Custom_Sign") or ""
	end)

	-- Paint / floors: one row per option with BUY / USE
	local function optionRows(category, items)
		for _, item in ipairs(items) do
			local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 52), LayoutOrder = nextOrder(), Parent = list }, item.Color)
			UIKit.create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = item.Color, Parent = card }, { UIKit.corner(8) })
			UIKit.label({ Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -230, 0, 24), Font = Theme.Title, Text = item.Name, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = card })
			UIKit.label({ Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -230, 0, 18), Text = priceText(item), TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = card })
			local button = UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 38), Parent = card }, function()
				local owned = player:GetAttribute("OwnsCustom_" .. item.Id) == true
				local using = player:GetAttribute("Custom_" .. category) == item.Id
				if not owned then
					Net.Fire("CustomAction", "Buy", item.Id)
				else
					Net.Fire("CustomAction", "Equip", category, if using then "" else item.Id)
				end
			end)
			table.insert(updaters, function()
				local owned = player:GetAttribute("OwnsCustom_" .. item.Id) == true
				local using = player:GetAttribute("Custom_" .. category) == item.Id
				if using then
					button.Text = "USING ✓"
					button:SetAttribute("BaseColor", Theme.Green)
					button:SetAttribute("Disabled", false)
				elseif owned then
					button.Text = "USE"
					button:SetAttribute("BaseColor", Theme.Blue)
					button:SetAttribute("Disabled", false)
				else
					button.Text = if item.VIP then "VIP ONLY 🔒" else "BUY"
					button:SetAttribute("BaseColor", Theme.Accent)
					button:SetAttribute("Disabled", item.VIP == true)
				end
			end)
		end
	end
	section("🧱 WALL PAINT")
	optionRows("Wall", CustomConfig.Walls)
	section("⚙️ MACHINE PAINT")
	optionRows("Machine", CustomConfig.Machines)
	section("🟫 FLOORS")
	optionRows("Floor", CustomConfig.Floors)

	-- Decorations: buy them, then pick one for each slot
	section("🪴 DECORATIONS")
	for _, item in ipairs(CustomConfig.Decor) do
		local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 46), LayoutOrder = nextOrder(), Parent = list })
		UIKit.label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -230, 1, 0), Font = Theme.Title, Text = item.Name .. "  •  " .. priceText(item), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
		local button = UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 34), Parent = card }, function()
			Net.Fire("CustomAction", "Buy", item.Id)
		end)
		table.insert(updaters, function()
			local owned = player:GetAttribute("OwnsCustom_" .. item.Id) == true
			button.Text = if owned then "OWNED ✓" elseif item.VIP then "VIP ONLY 🔒" else "BUY"
			button:SetAttribute("Disabled", owned or item.VIP == true)
		end)
	end

	section("📍 DECORATION SPOTS (tap to change)")
	local function ownedDecor()
		local owned = { "" }
		for _, item in ipairs(CustomConfig.Decor) do
			if player:GetAttribute("OwnsCustom_" .. item.Id) then
				table.insert(owned, item.Id)
			end
		end
		return owned
	end
	local names = { [""] = "Empty" }
	for _, item in ipairs(CustomConfig.Decor) do
		names[item.Id] = item.Name
	end
	local slotGrid = UIKit.create("Frame", { Size = UDim2.new(1, -10, 0, 100), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = list }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.new(0.333, -6, 0, 44), CellPadding = UDim2.fromOffset(6, 6) }),
	})
	for slot in ipairs(CustomConfig.DecorSlots) do
		local button = UIKit.button({ Color = Theme.PanelLight, Parent = slotGrid }, function()
			local options = ownedDecor()
			local current = player:GetAttribute("Custom_Decor" .. slot) or ""
			local index = table.find(options, current) or 1
			Net.Fire("CustomAction", "Decor", slot, options[index % #options + 1])
		end)
		table.insert(updaters, function()
			button.Text = ("Spot %d: %s"):format(slot, names[player:GetAttribute("Custom_Decor" .. slot) or ""] or "?")
		end)
	end

	local function update()
		for _, fn in ipairs(updaters) do
			fn()
		end
	end
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 7) == "Custom_" or string.sub(name, 1, 11) == "OwnsCustom_" then
			update()
		end
	end)
	update()
	return window
end

return CustomizePanel
