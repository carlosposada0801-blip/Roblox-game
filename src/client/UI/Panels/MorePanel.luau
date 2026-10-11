--[[
	MorePanel
	Hub for the extra windows. Buttons call MenuController via a callback
	set by MenuController (MorePanel.OnOpen).
]]

local UIKit = require(script.Parent.Parent.UIKit)

local Theme = UIKit.Theme

local MorePanel = {}
MorePanel.OnOpen = nil -- set by MenuController

MorePanel.Entries = {
	{ Name = "Battle", Icon = "🥊", Color = Theme.Purple, Panel = "BattlePanel" },
	{ Name = "Yard", Icon = "📦", Color = Theme.Accent, Panel = "YardPanel" },
	{ Name = "Sky", Icon = "☁️", Color = Theme.Cyan, Panel = "SkyPanel" },
	{ Name = "Achievements", Icon = "🏅", Color = Theme.Accent, Panel = "AchievementsPanel" },
	{ Name = "Style", Icon = "✨", Color = Theme.Pink, Panel = "CosmeticsPanel" },
	{ Name = "Customize", Icon = "🎨", Color = Color3.fromRGB(255, 120, 160), Panel = "CustomizePanel" },
	{ Name = "Contracts", Icon = "📜", Color = Color3.fromRGB(200, 150, 80), Panel = "ContractsPanel" },
	{ Name = "Race", Icon = "🏁", Color = Color3.fromRGB(255, 200, 40), Panel = "RacePanel" },
	{ Name = "Mine", Icon = "⛏️", Color = Theme.Purple, Panel = "MinePanel" },
	{ Name = "Crew", Icon = "🛡️", Color = Theme.Blue, Panel = "CrewPanel" },
	{ Name = "Codes", Icon = "🎟️", Color = Theme.Green, Panel = "CodesPanel" },
	{ Name = "Settings", Icon = "⚙️", Color = Theme.Disabled, Panel = "SettingsPanel" },
}

function MorePanel.build()
	local window, content = UIKit.window("☰ MORE", Theme.Cyan, Vector2.new(620, 480))
	local grid = UIKit.create("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(132, 96), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, entry in ipairs(MorePanel.Entries) do
		local button = UIKit.button({ Name = entry.Name, Color = entry.Color, Text = entry.Icon .. "\n" .. string.upper(entry.Name), LayoutOrder = index, Parent = grid }, function()
			if MorePanel.OnOpen then
				MorePanel.OnOpen(entry.Name)
			end
		end)
		button.TextWrapped = true
	end
	return window
end

return MorePanel
