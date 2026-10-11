--[[
	CoopController
	Popup when someone invites you to build their factory, and a small
	"Leave co-op" button while you're building with someone.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)
local Sfx = require(script.Parent.Parent.Sfx)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local CoopController = {}

function CoopController:Start()
	Net.On("CoopInviteReceived", function(fromUserId, fromName)
		local dialog = UIKit.card({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 300),
			Size = UDim2.fromOffset(400, 120),
			BackgroundColor3 = Theme.Background,
			ZIndex = 60,
			Parent = UIKit.root(),
		}, Theme.Green)
		UIKit.label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), Font = Theme.Title, Text = "🤝 " .. tostring(fromName) .. " wants you to build their factory!", TextWrapped = true, MaxTextSize = 20, ZIndex = 61, Parent = dialog })
		local function respond(accept)
			Net.Fire("CoopRespond", fromUserId, accept)
			dialog:Destroy()
		end
		UIKit.button({ Position = UDim2.new(0, 12, 1, -56), Size = UDim2.new(0.5, -18, 0, 44), Color = Theme.Green, Text = "JOIN", ZIndex = 61, Parent = dialog }, function()
			respond(true)
		end)
		UIKit.button({ Position = UDim2.new(0.5, 6, 1, -56), Size = UDim2.new(0.5, -18, 0, 44), Color = Theme.Red, Text = "NO THANKS", ZIndex = 61, Parent = dialog }, function()
			respond(false)
		end)
		Sfx.play("Purchase")
		task.delay(20, function()
			if dialog.Parent then
				dialog:Destroy()
			end
		end)
	end)

	local leave = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 240),
		Size = UDim2.fromOffset(260, 40),
		Color = Theme.Green,
		Text = "🤝 CO-OP: LEAVE",
		Visible = false,
		Parent = UIKit.root(),
	}, function()
		Net.Fire("CoopLeave")
	end)
	local function update()
		local ownerId = player:GetAttribute("BuildingFor")
		local owner = ownerId and Players:GetPlayerByUserId(ownerId)
		leave.Visible = owner ~= nil
		if owner then
			leave.Text = "🤝 Building with " .. owner.DisplayName .. "  •  LEAVE"
		end
	end
	player:GetAttributeChangedSignal("BuildingFor"):Connect(update)
	update()
end

return CoopController
