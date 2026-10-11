--[[
	GuideController
	A small bouncing arrow over the next buy button: the cheapest one you can
	afford, or the cheapest one overall if you can't afford any yet. A
	"Guide" button under the side menu turns it on or off (saved per player).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local GuideController = {}

local function isOn()
	return player:GetAttribute("Setting_GuideArrow") ~= false
end

function GuideController:Start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local plotModel = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. player:GetAttribute("PlotId"))
	local buttons = plotModel:WaitForChild("Buttons")
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")

	-- The arrow: a small billboard that floats above the chosen button
	local arrow = UIKit.create("BillboardGui", {
		Name = "GuideArrow",
		Size = UDim2.fromOffset(34, 34),
		StudsOffset = Vector3.new(0, 6.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 250,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	UIKit.label({
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Title,
		Text = "▼",
		TextColor3 = Color3.fromRGB(255, 220, 60),
		TextStrokeTransparency = 0.2,
		MaxTextSize = 34,
		Parent = arrow,
	})

	-- Gentle bounce
	TweenService:Create(
		arrow,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 7.5, 0) }
	):Play()

	local function pickTarget()
		local cheapestAffordable, cheapest
		for _, button in ipairs(buttons:GetChildren()) do
			local pad = button:FindFirstChild("Pad")
			local price = button:GetAttribute("Price")
			if pad and price then
				if price <= cash.Value and (not cheapestAffordable or price < cheapestAffordable.Price) then
					cheapestAffordable = { Pad = pad, Price = price }
				end
				if not cheapest or price < cheapest.Price then
					cheapest = { Pad = pad, Price = price }
				end
			end
		end
		local target = cheapestAffordable or cheapest
		return target and target.Pad
	end

	local function update()
		local target = isOn() and pickTarget() or nil
		arrow.Adornee = target
		arrow.Enabled = target ~= nil
	end

	-- On/off toggle under the side menu
	local toggle
	toggle = UIKit.button({
		Name = "GuideToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 178),
		Size = UDim2.fromOffset(92, 44),
		Color = Theme.PanelLight,
		Parent = UIKit.root(),
	}, function()
		Net.Fire("SetSetting", "GuideArrow", not isOn())
	end)
	local function updateToggle()
		toggle.Text = if isOn() then "🧭 Guide ✓" else "🧭 Guide ✗"
		update()
	end
	player:GetAttributeChangedSignal("Setting_GuideArrow"):Connect(updateToggle)
	updateToggle()

	buttons.ChildAdded:Connect(function(button)
		button:WaitForChild("Pad", 5)
		update()
	end)
	buttons.ChildRemoved:Connect(update)
	cash.Changed:Connect(update)
	update()
end

return GuideController
