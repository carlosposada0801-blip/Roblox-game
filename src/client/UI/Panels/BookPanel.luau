--[[
	BookPanel
	Robot Collection Book: one cell for every rarity x color robot. Sold
	robots fill in their cell; every entry gives a permanent cash bonus.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)
local ProductionConfig = require(Shared.Config.ProductionConfig)
local UIKit = require(script.Parent.Parent.UIKit)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local BookPanel = {}

local colorByName = { Steel = Color3.fromRGB(160, 165, 175) }
for _, paint in ipairs(ProductionConfig.PaintColors) do
	colorByName[paint.Name] = paint.Color
end

function BookPanel.build()
	local window, content = UIKit.window("📖 ROBOT COLLECTION", Theme.Cyan, Vector2.new(660, 500))

	local header = UIKit.label({ Size = UDim2.new(1, 0, 0, 26), Font = Theme.Title, MaxTextSize = 22, Parent = content })
	UIKit.label({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = Theme.SubText,
		MaxTextSize = 14,
		Text = "Sell robots of every rarity and paint color. Each new robot = +1% cash forever!",
		Parent = content,
	})

	local grid = UIKit.create("Frame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Parent = content,
	})

	local colors = RarityConfig.Colors
	local cellW, cellH, labelW = 62, 62, 100
	-- Column headers (colors)
	for c, name in ipairs(colors) do
		UIKit.label({
			Position = UDim2.fromOffset(labelW + (c - 1) * (cellW + 4), 0),
			Size = UDim2.fromOffset(cellW, 16),
			Text = name,
			TextColor3 = colorByName[name],
			Font = Theme.Title,
			MaxTextSize = 13,
			Parent = grid,
		})
	end

	local cells = {}
	for r, rarity in ipairs(RarityConfig.Rarities) do
		local y = 20 + (r - 1) * (cellH + 6)
		UIKit.label({
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(labelW - 6, cellH),
			Text = string.upper(rarity.Id) .. ("\nx%g"):format(rarity.ValueMultiplier),
			TextColor3 = rarity.Color,
			Font = Theme.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = grid,
		})
		for c, colorName in ipairs(colors) do
			local cell = UIKit.create("Frame", {
				Position = UDim2.fromOffset(labelW + (c - 1) * (cellW + 4), y),
				Size = UDim2.fromOffset(cellW, cellH),
				BackgroundColor3 = Theme.Panel,
				Parent = grid,
			}, { UIKit.corner(10), UIKit.stroke(rarity.Color, 2) })
			-- Little robot face: body in the paint color, eyes in the rarity color
			local face = UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(30, 26),
				BackgroundColor3 = colorByName[colorName],
				Parent = cell,
			}, { UIKit.corner(6) })
			UIKit.create("Frame", { Position = UDim2.fromOffset(5, 9), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = rarity.Color, Parent = face }, { UIKit.corner(3) })
			local count = UIKit.label({ Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Title, MaxTextSize = 14, Parent = cell })
			cells[rarity.Id .. "|" .. colorName] = { Cell = cell, Face = face, Count = count }
		end
	end

	local total = #RarityConfig.Rarities * #colors
	local function update()
		local ok, collection = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("CollectionJson") or "{}")
		collection = ok and type(collection) == "table" and collection or {}
		local found = 0
		for key, entry in pairs(cells) do
			local sold = collection[key]
			if sold then
				found += 1
				entry.Face.Visible = true
				entry.Count.Text = "x" .. sold
				entry.Cell.BackgroundTransparency = 0
			else
				entry.Face.Visible = false
				entry.Count.Text = "?"
				entry.Cell.BackgroundTransparency = 0.5
			end
		end
		header.Text = ("%d / %d ROBOTS FOUND  •  +%d%% CASH"):format(found, total, math.floor(found * RarityConfig.BonusPerEntry * 100 + 0.5))
	end
	player:GetAttributeChangedSignal("CollectionJson"):Connect(update)
	update()

	return window
end

return BookPanel
