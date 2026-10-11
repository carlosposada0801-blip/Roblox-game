--[[
	ShopPanel
	Game passes and developer products. Buying sends RequestPurchase; the
	server shows the Roblox purchase prompt and grants the reward
	(ProcessReceipt for products). Nothing is granted from the client.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local ShopPanel = {}

local function sortedEntries(tbl)
	local entries = {}
	for key, entry in pairs(tbl) do
		table.insert(entries, { Key = key, Entry = entry })
	end
	table.sort(entries, function(a, b)
		return (a.Entry.Order or 0) < (b.Entry.Order or 0)
	end)
	return entries
end

local function makeHeader(parent, text, order)
	UIKit.label({
		Size = UDim2.new(1, -10, 0, 34),
		Font = Theme.Title,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Accent,
		MaxTextSize = 26,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function makeCard(parent, entry, order, color, onBuy)
	local card = UIKit.create("Frame", {
		Size = UDim2.new(1, -10, 0, 82),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.corner(12), UIKit.stroke(color, 2) })

	UIKit.label({ Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(60, 60), Text = entry.Icon or "", MaxTextSize = 44, Parent = card })
	UIKit.label({
		Position = UDim2.fromOffset(80, 10),
		Size = UDim2.new(1, -240, 0, 28),
		Font = Theme.Title,
		Text = entry.DisplayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = card,
	})
	UIKit.label({
		Position = UDim2.fromOffset(80, 40),
		Size = UDim2.new(1, -240, 0, 34),
		Text = entry.Description,
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 15,
		Parent = card,
	})

	return UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 48),
		Color = Theme.Green,
		Text = entry.PriceText or "Buy",
		Parent = card,
	}, onBuy)
end

function ShopPanel.build()
	local window, content = UIKit.window("🛒 Shop", Theme.Accent, Vector2.new(640, 520))

	local list = UIKit.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	makeHeader(list, "Game Passes (forever)", 0)
	local passButtons = {}
	for index, item in ipairs(sortedEntries(MonetizationConfig.GamePasses)) do
		passButtons[item.Key] = {
			Entry = item.Entry,
			Button = makeCard(list, item.Entry, index, Theme.Accent, function()
				Net.Fire("RequestPurchase", "Pass", item.Key)
			end),
		}
	end

	makeHeader(list, "Boosts & Items", 100)
	local starterCard
	for index, item in ipairs(sortedEntries(MonetizationConfig.Products)) do
		local button = makeCard(list, item.Entry, 100 + index, if item.Key == "StarterPack" then Theme.Green else Theme.Blue, function()
			Net.Fire("RequestPurchase", "Product", item.Key)
		end)
		if item.Key == "StarterPack" then
			starterCard = button.Parent
		end
	end
	if starterCard then
		local function updateStarter()
			starterCard.Visible = player:GetAttribute("StarterPackBought") ~= true
		end
		player:GetAttributeChangedSignal("StarterPackBought"):Connect(updateStarter)
		updateStarter()
	end

	-- Roblox Premium perk
	makeHeader(list, "Roblox Premium", 200)
	local premiumButton = makeCard(list, {
		Icon = "⭐",
		DisplayName = "Premium Bonus",
		Description = ("Roblox Premium members earn +%d%% cash in this game!"):format(MonetizationConfig.PremiumBonus * 100),
		PriceText = "GET PREMIUM",
	}, 201, Theme.Accent, function()
		pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player)
	end)
	if player.MembershipType == Enum.MembershipType.Premium then
		premiumButton.Text = "ACTIVE ✓"
		premiumButton:SetAttribute("Disabled", true)
	end

	local function updatePasses()
		for key, pass in pairs(passButtons) do
			local owned = player:GetAttribute("Pass_" .. key) == true
			pass.Button.Text = if owned then "OWNED ✓" else pass.Entry.PriceText
			pass.Button:SetAttribute("Disabled", owned)
		end
	end
	for key in pairs(passButtons) do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(updatePasses)
	end
	updatePasses()

	return window
end

return ShopPanel
