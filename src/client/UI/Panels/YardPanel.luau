--[[
	YardPanel
	Logistics Yard shop: pick a conveyor piece to start building
	(YardController), or teleport to your yard behind the factory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local YardConfig = require(Shared.Config.YardConfig)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local YardPanel = {}

local DESCRIPTIONS = {
	Conveyor = "Moves crates forward. Takes them from behind or the sides.",
	SpeedConveyor = "Twice as fast. Fixes slow lines!",
	Splitter = "Sends crates left, right, left, right...",
	Sorter = "Rare & Epic go straight, Common turn right.",
	Merger = "Takes crates from 3 sides, pushes them forward fast.",
}

function YardPanel.build()
	local window, content = UIKit.window("📦 LOGISTICS YARD", Theme.Accent, Vector2.new(620, 500))
	local YardController = require(script.Parent.Parent.Parent.Controllers.YardController)

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 48),
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		MaxTextSize = 15,
		Text = ("Behind your factory is a yard. Its dropper makes crates; build a path to the 💵 Seller, or sort Rare/Epic crates to the 💎 Rare Buyer for x%d cash! Removing a piece refunds it."):format(YardConfig.RareBuyerBonus),
		Parent = content,
	})

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for pieceType, config in pairs(YardConfig.Pieces) do
		local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = config.Order, Parent = list }, config.Color)
		UIKit.label({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48), Text = config.Icon, MaxTextSize = 36, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -240, 0, 26), Font = Theme.Title, Text = config.Name .. "  •  " .. Format.cash(config.Price), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = card })
		UIKit.label({ Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -240, 0, 22), Text = DESCRIPTIONS[pieceType] or "", TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, MaxTextSize = 14, Parent = card })
		UIKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 44), Color = Theme.Green, Text = "BUILD", Parent = card }, function()
			YardController:Select(pieceType)
			window.Visible = false
		end)
	end

	local countLabel = UIKit.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(0.45, 0, 0, 50), Font = Theme.Title, MaxTextSize = 18, Parent = content })
	UIKit.button({
		Name = "GoToYard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, 0, 0, 54),
		Color = Theme.Blue,
		Text = "🚶 GO TO MY YARD",
		Parent = content,
	}, function()
		local plots = workspace:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
		local floor = plot and plot:FindFirstChild("Yard") and plot.Yard:FindFirstChild("YardFloor")
		local character = player.Character
		if floor and character then
			-- Stand on the side of the yard nearest the factory, facing into it
			local spot = floor.CFrame * CFrame.new(0, 4, floor.Size.Z / 2 + 2)
			character:PivotTo(CFrame.lookAt(spot.Position, floor.Position + Vector3.new(0, 4, 0)))
		end
		window.Visible = false
	end)
	local function update()
		countLabel.Text = ("Pieces placed: %d"):format(player:GetAttribute("YardPieces") or 0)
	end
	player:GetAttributeChangedSignal("YardPieces"):Connect(update)
	update()

	return window
end

return YardPanel
