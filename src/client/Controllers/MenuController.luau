--[[
	MenuController
	Left-side menu: a 2-column grid of buttons that open the game's windows.
	Only one window is open at a time. Other controllers can call
	MenuController:Open("Daily") etc.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Panels = script.Parent.Parent.UI.Panels

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local MENU = {
	{ Name = "Rebirth", Icon = "🔄", Color = Theme.Purple, Panel = "RebirthPanel" },
	{ Name = "Workers", Icon = "🤖", Color = Theme.Blue, Panel = "WorkersPanel" },
	{ Name = "Shop", Icon = "🛒", Color = Theme.Accent, Panel = "ShopPanel" },
	{ Name = "Pets", Icon = "🛸", Color = Color3.fromRGB(170, 90, 255), Panel = "PetsPanel" },
	{ Name = "Quests", Icon = "📋", Color = Theme.Green, Panel = "QuestsPanel", Badge = "Quests" },
	{ Name = "Book", Icon = "📖", Color = Theme.Cyan, Panel = "BookPanel" },
	{ Name = "Players", Icon = "👥", Color = Color3.fromRGB(60, 120, 255), Panel = "PlayersPanel" },
	{ Name = "Daily", Icon = "🎁", Color = Theme.Pink, Panel = "DailyPanel", Badge = "Daily" },
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

function MenuController:Open(name: string)
	local window = windows[name]
	if window and not window.Visible then
		self:Toggle(name)
	end
end

-- Red "!" dot on a menu button when something is waiting
local function makeBadge(button)
	return UIKit.create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Red,
		Font = Theme.Title,
		Text = "!",
		TextColor3 = Theme.Text,
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { UIKit.corner(11), UIKit.stroke(Color3.new(1, 1, 1), 2) })
end

local function questsReady()
	-- A quest is ready when progress has reached the goal and it isn't claimed yet
	local json = player:GetAttribute("QuestsJson") or ""
	local ok, quests = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(quests) ~= "table" then
		return false
	end
	for _, quest in ipairs(quests) do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			return true
		end
	end
	return false
end

function MenuController:Start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local root = UIKit.root()

	local bar = UIKit.create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -10),
		Size = UDim2.fromOffset(156, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(74, 66),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	for index, entry in ipairs(MENU) do
		local ok, window = pcall(function()
			return require(Panels[entry.Panel]).build()
		end)
		if not ok then
			warn("[Menu] Couldn't build " .. entry.Panel .. ": " .. tostring(window))
			continue
		end
		window.Parent = root
		windows[entry.Name] = window

		local button = UIKit.button({
			Name = entry.Name,
			Color = entry.Color,
			Text = entry.Icon .. "\n" .. string.upper(entry.Name),
			LayoutOrder = index,
			Parent = bar,
		}, function()
			self:Toggle(entry.Name)
		end)
		button.TextWrapped = true

		if entry.Badge == "Daily" then
			local badge = makeBadge(button)
			local function update()
				badge.Visible = player:GetAttribute("DailyAvailable") == true
			end
			player:GetAttributeChangedSignal("DailyAvailable"):Connect(update)
			update()
		elseif entry.Badge == "Quests" then
			local badge = makeBadge(button)
			local function update()
				badge.Visible = questsReady()
			end
			player:GetAttributeChangedSignal("QuestsJson"):Connect(update)
			update()
		end
	end

	-- Daily reward waiting? Pop it open after a moment.
	task.delay(3, function()
		if player:GetAttribute("DailyAvailable") then
			self:Open("Daily")
		end
	end)
end

return MenuController
