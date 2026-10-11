--[[
	WorkersPanel
	Hire worker bots with robots your factory has built. The server checks
	the robot cost and slot limit; this panel only shows state and sends
	HireWorker / DismissWorker.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorkerConfig = require(Shared.Config.WorkerConfig)
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local WorkersPanel = {}

function WorkersPanel.build()
	local window, content = UIKit.window("🤖 Workers", Theme.Blue, Vector2.new(600, 500))

	local robotsLabel = UIKit.label({ Size = UDim2.new(1, 0, 0, 34), Font = Theme.Title, MaxTextSize = 30, Parent = content })
	UIKit.label({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.SubText,
		MaxTextSize = 16,
		Text = "Every robot you build adds 1. Assign robots to worker slots! More slots unlock with rebirths.",
		Parent = content,
	})

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local cards = {}
	for index, worker in ipairs(WorkerConfig.Workers) do
		local card = UIKit.create("Frame", {
			Size = UDim2.new(1, -10, 0, 92),
			BackgroundColor3 = Theme.Panel,
			LayoutOrder = index,
			Parent = list,
		}, { UIKit.corner(12), UIKit.stroke(worker.Color, 2) })

		UIKit.label({ Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(64, 64), Text = worker.Icon, MaxTextSize = 48, Parent = card })
		UIKit.label({
			Position = UDim2.fromOffset(84, 8),
			Size = UDim2.new(1, -260, 0, 28),
			Font = Theme.Title,
			Text = worker.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = card,
		})
		UIKit.label({
			Position = UDim2.fromOffset(84, 36),
			Size = UDim2.new(1, -260, 0, 22),
			Text = worker.Description,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = card,
		})
		local bonusLabel = UIKit.label({
			Position = UDim2.new(0, 84, 0, 60),
			Size = UDim2.new(1, -260, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(120, 255, 140),
			Font = Theme.Title,
			MaxTextSize = 16,
			Parent = card,
		})
		local countLabel = UIKit.label({
			Position = UDim2.fromOffset(84, 60),
			Size = UDim2.new(1, -260, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = worker.Color,
			Font = Theme.Title,
			MaxTextSize = 18,
			Parent = card,
		})

		local hire = UIKit.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(160, 42),
			Color = Theme.Green,
			Parent = card,
		}, function()
			Net.Fire("HireWorker", worker.Id)
		end)

		local dismiss = UIKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(160, 28),
			Color = Theme.Red,
			Text = "Remove one",
			Parent = card,
		}, function()
			Net.Fire("DismissWorker", worker.Id)
		end)

		cards[worker.Id] = { Worker = worker, Count = countLabel, Bonus = bonusLabel, Hire = hire, Dismiss = dismiss }
	end

	local function bonusText(worker, count)
		local amount = math.floor(count * worker.Effect.Amount * 100 + 0.5)
		if count == 0 then
			return ""
		elseif worker.Effect.Type == "DropperSpeed" then
			return ("Bonus: +%d%% dropper speed"):format(amount)
		elseif worker.Effect.Type == "AutoCollect" then
			return ("Bonus: grabs %d%% of pad cash"):format(math.min(100, amount))
		elseif worker.Effect.Machine == "*" then
			return ("Bonus: +%d%% every machine"):format(amount)
		end
		return ("Bonus: +%d%% %s value"):format(amount, worker.Effect.Machine)
	end

	local function update()
		local robots = player:GetAttribute("Robots") or 0
		robotsLabel.Text = "🤖 Robots available: " .. robots

		for _, card in pairs(cards) do
			local worker = card.Worker
			local count = player:GetAttribute("Worker_" .. worker.Id) or 0
			local max = #worker.Slots
			local unlocked = player:GetAttribute("WorkerSlots_" .. worker.Id) or max
			card.Count.Text = ("Slots %d / %d  (%d unlocked)"):format(count, max, unlocked)
			card.Bonus.Text = bonusText(worker, count)

			if count >= max then
				card.Hire.Text = "MAXED"
				card.Hire:SetAttribute("Disabled", true)
			elseif count >= unlocked then
				card.Hire.Text = ("🔒 %d rebirths"):format(WorkerConfig.SlotRebirths[count + 1] or 0)
				card.Hire:SetAttribute("Disabled", true)
			else
				card.Hire.Text = ("Hire  •  %d 🤖"):format(worker.Cost)
				card.Hire:SetAttribute("Disabled", robots < worker.Cost)
			end
			card.Dismiss.Visible = count > 0
		end
	end

	player:GetAttributeChangedSignal("Robots"):Connect(update)
	for _, worker in ipairs(WorkerConfig.Workers) do
		player:GetAttributeChangedSignal("Worker_" .. worker.Id):Connect(update)
		player:GetAttributeChangedSignal("WorkerSlots_" .. worker.Id):Connect(update)
	end
	update()

	return window
end

return WorkersPanel
