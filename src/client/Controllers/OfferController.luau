--[[
	OfferController
	Shows the Starter Pack popup when the server sends ShowOffer("StarterPack")
	(OfferService decides when: 3 minutes into the first visit and once on the
	second visit). Buying goes through the normal shop purchase.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Format = require(ReplicatedStorage.Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local OfferController = {}

local function showStarterPack()
	local product = MonetizationConfig.Products.StarterPack
	if not product or player:GetAttribute("StarterPackBought") or UIKit.root():FindFirstChild("StarterOffer") then
		return
	end

	local overlay = UIKit.create("TextButton", {
		Name = "StarterOffer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 60,
		Parent = UIKit.root(),
	})
	local card = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 330),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 61,
		Parent = overlay,
	}, {
		UIKit.corner(18),
		UIKit.stroke(Theme.Accent, 4),
		UIKit.gradient(Color3.fromRGB(40, 30, 80), Color3.fromRGB(20, 18, 40)),
		UIKit.padding(16),
	})
	local scale = UIKit.create("UIScale", { Scale = 0.6, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	UIKit.label({ Size = UDim2.new(1, 0, 0, 40), Font = Theme.Title, Text = "🎒 STARTER PACK", TextColor3 = Theme.Accent, MaxTextSize = 36, ZIndex = 62, Parent = card })
	UIKit.label({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22), Text = "One-time deal: only for new bosses!", TextColor3 = Theme.SubText, MaxTextSize = 17, ZIndex = 62, Parent = card })
	UIKit.label({
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 120),
		Font = Theme.Title,
		Text = Format.reward(product.Reward, "\n"):gsub("Robot skin", "Founder Gold robot skin"),
		TextColor3 = Color3.fromRGB(255, 230, 140),
		TextWrapped = true,
		MaxTextSize = 26,
		ZIndex = 62,
		Parent = card,
	})

	local function close()
		overlay:Destroy()
	end
	UIKit.button({
		Name = "NoThanks",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.38, 0, 0, 52),
		Color = Theme.Disabled,
		Text = "No thanks",
		ZIndex = 62,
		Parent = card,
	}, close)
	UIKit.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.58, 0, 0, 52),
		Color = Theme.Green,
		Text = "GET IT  " .. (product.PriceText or ""),
		ZIndex = 62,
		Parent = card,
	}, function()
		close()
		Net.Fire("RequestPurchase", "Product", "StarterPack")
	end)
end

function OfferController:Start()
	Net.On("ShowOffer", function(offerId)
		if offerId == "StarterPack" then
			showStarterPack()
		end
	end)
end

return OfferController
