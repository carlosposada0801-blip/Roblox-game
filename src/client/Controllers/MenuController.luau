--[[
	MenuController
	Left-side menu buttons that open the Rebirth, Workers and Shop windows.
	Only one window is open at a time.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Panels = script.Parent.Parent.UI.Panels

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local MENU = {
	{ Name = "Rebirth", Icon = "🔄", Color = Theme.Purple, Panel = "RebirthPanel" },
	{ Name = "Workers", Icon = "🤖", Color = Theme.Blue, Panel = "WorkersPanel" },
	{ Name = "Shop", Icon = "🛒", Color = Theme.Accent, Panel = "ShopPanel" },
}

local MenuController = {}

local windows = {}

function MenuController:Toggle(name: string)
	for windowName, window in pairs(windows) do
		if windowName == name and not window.Visible then
			UIKit.open(window)
		else
			UIKit.close(window)
		end
	end
end

function MenuController:Start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local root = UIKit.root()

	local bar = UIKit.create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(92, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UIKit.create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	for index, entry in ipairs(MENU) do
		local window = require(Panels[entry.Panel]).build()
		window.Parent = root
		windows[entry.Name] = window

		local button = UIKit.button({
			Name = entry.Name,
			Size = UDim2.fromOffset(92, 84),
			Color = entry.Color,
			Text = entry.Icon .. "\n" .. entry.Name,
			LayoutOrder = index,
			Parent = bar,
		}, function()
			self:Toggle(entry.Name)
		end)
		button.TextWrapped = true
	end
end

return MenuController
