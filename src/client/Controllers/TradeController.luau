--[[
	TradeController
	Trade invites and the trade window. Everything is decided by the server
	(TradeService); this just shows the state and sends requests.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)
local Sfx = require(script.Parent.Parent.Sfx)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local TradeController = {}

local function inviteDialog(fromUserId, fromName)
	local root = UIKit.root()
	local dialog = UIKit.card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(380, 120),
		BackgroundColor3 = Theme.Background,
		ZIndex = 60,
		Parent = root,
	}, Theme.Accent)
	UIKit.label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), Font = Theme.Title, Text = "🤝 " .. fromName .. " wants to trade!", MaxTextSize = 22, ZIndex = 61, Parent = dialog })
	local function respond(accept)
		Net.Fire("TradeRespond", fromUserId, accept)
		dialog:Destroy()
	end
	UIKit.button({ Position = UDim2.new(0, 12, 1, -58), Size = UDim2.new(0.5, -18, 0, 46), Color = Theme.Green, Text = "ACCEPT", ZIndex = 61, Parent = dialog }, function()
		respond(true)
	end)
	UIKit.button({ Position = UDim2.new(0.5, 6, 1, -58), Size = UDim2.new(0.5, -18, 0, 46), Color = Theme.Red, Text = "DECLINE", ZIndex = 61, Parent = dialog }, function()
		respond(false)
	end)
	Sfx.play("Purchase")
	task.delay(20, function()
		if dialog.Parent then
			dialog:Destroy()
		end
	end)
end

function TradeController:Start()
	local window, content = UIKit.window("🤝 TRADE", Theme.Accent, Vector2.new(600, 420))
	window.Parent = UIKit.root()
	window:FindFirstChild("Close", true).Activated:Connect(function()
		Net.Fire("TradeCancel")
	end)

	local partnerLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 28), Font = Theme.Title, MaxTextSize = 24, Parent = content })

	local myOffer = { Robots = 0, Prototypes = 0 }

	local function column(x, title)
		local card = UIKit.card({ Position = UDim2.new(x, x == 0 and 0 or 6, 0, 36), Size = UDim2.new(0.5, -6, 0, 210), Parent = content }, Theme.PanelLight)
		UIKit.label({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 26), Font = Theme.Title, Text = title, MaxTextSize = 20, Parent = card })
		return card
	end
	local mine = column(0, "YOUR OFFER")
	local theirs = column(0.5, "THEIR OFFER")

	local myLabels, theirLabels = {}, {}
	for row, item in ipairs({ { Key = "Robots", Icon = "🤖" }, { Key = "Prototypes", Icon = "⭐" } }) do
		local y = 50 + (row - 1) * 74
		myLabels[item.Key] = UIKit.label({ Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 30), Font = Theme.Title, MaxTextSize = 24, Parent = mine })
		theirLabels[item.Key] = UIKit.label({ Position = UDim2.fromOffset(10, y + 10), Size = UDim2.new(1, -20, 0, 30), Font = Theme.Title, MaxTextSize = 24, Parent = theirs })
		for i, step in ipairs({ -10, -1, 1, 10 }) do
			UIKit.button({
				Position = UDim2.new((i - 1) * 0.25, 4, 0, y + 32),
				Size = UDim2.new(0.25, -8, 0, 32),
				Color = if step > 0 then Theme.Green else Theme.Red,
				Text = (step > 0 and "+" or "") .. step,
				Parent = mine,
			}, function()
				local owned = player:GetAttribute(item.Key) or 0
				myOffer[item.Key] = math.clamp(myOffer[item.Key] + step, 0, owned)
				Net.Fire("TradeOffer", myOffer.Robots, myOffer.Prototypes)
			end)
		end
	end

	local status = UIKit.label({ Position = UDim2.fromOffset(0, 252), Size = UDim2.new(1, 0, 0, 24), Font = Theme.Title, MaxTextSize = 20, Parent = content })
	local ready = UIKit.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.6, -6, 0, 52),
		Color = Theme.Green,
		Text = "READY",
		Parent = content,
	}, function() end)
	UIKit.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.4, -6, 0, 52),
		Color = Theme.Red,
		Text = "CANCEL",
		Parent = content,
	}, function()
		Net.Fire("TradeCancel")
	end)

	local current: any = {}
	ready.Activated:Connect(function()
		Net.Fire("TradeReady", not current.MyReady)
	end)

	Net.On("TradeInvite", inviteDialog)
	Net.On("TradeState", function(state)
		current = state or {}
		if not current.Active then
			window.Visible = false
			myOffer = { Robots = 0, Prototypes = 0 }
			return
		end
		if not window.Visible then
			UIKit.open(window)
		end
		partnerLabel.Text = "Trading with " .. tostring(current.PartnerName)
		local mineOffer = current.MyOffer or {}
		local theirOffer = current.TheirOffer or {}
		myOffer = { Robots = mineOffer.Robots or 0, Prototypes = mineOffer.Prototypes or 0 }
		myLabels.Robots.Text = "🤖 " .. myOffer.Robots
		myLabels.Prototypes.Text = "⭐ " .. myOffer.Prototypes
		theirLabels.Robots.Text = "🤖 " .. (theirOffer.Robots or 0)
		theirLabels.Prototypes.Text = "⭐ " .. (theirOffer.Prototypes or 0)
		ready.Text = if current.MyReady then "UNREADY" else "READY"
		ready:SetAttribute("BaseColor", if current.MyReady then Theme.Disabled else Theme.Green)
		if current.Countdown then
			status.Text = ("Trading in %d..."):format(current.Countdown)
			status.TextColor3 = Theme.Accent
		elseif current.TheirReady then
			status.Text = "They're ready! Press READY to confirm."
			status.TextColor3 = Theme.Green
		else
			status.Text = "Set your offer, then both press READY."
			status.TextColor3 = Theme.SubText
		end
	end)
end

return TradeController
