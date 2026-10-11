--[[
	SettingsPanel
	On/off switches for music, sound effects, screen shake and the guide
	arrow. Each one is saved on the server (SettingsService) so it sticks
	between visits.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local SettingsPanel = {}

local OPTIONS = {
	{ Key = "Music", Icon = "🎵", Name = "Music" },
	{ Key = "Sfx", Icon = "🔊", Name = "Sound effects" },
	{ Key = "ScreenShake", Icon = "📳", Name = "Screen shake" },
	{ Key = "GuideArrow", Icon = "🧭", Name = "Guide arrow" },
}

function SettingsPanel.build()
	local window, content = UIKit.window("⚙️ SETTINGS", Theme.PanelLight, Vector2.new(440, 360))
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

	for index, option in ipairs(OPTIONS) do
		local row = UIKit.card({ Size = UDim2.new(1, 0, 0, 56), LayoutOrder = index, Parent = content })
		UIKit.label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Font = Theme.Title,
			Text = option.Icon .. "  " .. option.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = row,
		})
		local toggle = UIKit.button({
			Name = option.Key,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 42),
			Parent = row,
		}, function()
			Net.Fire("SetSetting", option.Key, player:GetAttribute("Setting_" .. option.Key) == false)
		end)
		local function update()
			local on = player:GetAttribute("Setting_" .. option.Key) ~= false
			toggle.Text = if on then "ON" else "OFF"
			toggle:SetAttribute("BaseColor", if on then Theme.Green else Theme.Disabled)
		end
		player:GetAttributeChangedSignal("Setting_" .. option.Key):Connect(update)
		update()
	end

	return window
end

return SettingsPanel
