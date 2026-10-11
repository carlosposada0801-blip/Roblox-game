--[[
	NotificationController
	Toast messages from the server (Notify remote) or other controllers.
	kind: "info" | "success" | "error" | "special"
]]

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local KIND_COLORS = {
	info = Theme.Blue,
	success = Theme.Green,
	error = Theme.Red,
	special = Theme.Purple,
}
local MAX_TOASTS = 4
local DURATION = 3.5

local NotificationController = {}

local container

function NotificationController:Show(text: string, kind: string?)
	if not container then
		return
	end
	local color = KIND_COLORS[kind or "info"] or Theme.Blue

	local toasts = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local toast = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		LayoutOrder = math.floor(os.clock() * 1000),
		Parent = container,
	}, { UIKit.corner(12), UIKit.stroke(color, 2) })

	local label = UIKit.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -12),
		Text = text,
		TextColor3 = if kind == "special" then Color3.fromRGB(230, 190, 255) else Theme.Text,
		MaxTextSize = 20,
		Parent = toast,
	})

	task.delay(DURATION, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local stroke = toast:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function NotificationController:Start()
	container = UIKit.create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(480, 220),
		BackgroundTransparency = 1,
		Parent = UIKit.root(),
	}, {
		UIKit.create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	Net.On("Notify", function(text, kind)
		self:Show(tostring(text), kind)
	end)
end

return NotificationController
