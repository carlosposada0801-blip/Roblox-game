--[[
	PlayersPanel
	Every factory in the server: owner, likes, a Visit button, and a Trade
	button for other players.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local PlayersPanel = {}

function PlayersPanel.build()
	local window, content = UIKit.window("👥 FACTORIES", Theme.Blue, Vector2.new(560, 470))

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.SubText,
		MaxTextSize = 15,
		Text = "Visit other factories and press F at their gate to like them. The most-liked factory wears a crown! 👑",
		TextWrapped = true,
		Parent = content,
	})

	local list = UIKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Built from players (not plot models): far-away plots may not be streamed in yet
	local function update()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, owner in ipairs(Players:GetPlayers()) do
			local plotId = owner:GetAttribute("PlotId")
			if plotId then
				local isMe = owner == player
				local card = UIKit.card({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = plotId, Parent = list }, if isMe then Theme.Cyan else Theme.Blue)
				UIKit.label({
					Position = UDim2.fromOffset(14, 6),
					Size = UDim2.new(1, -260, 0, 28),
					Font = Theme.Title,
					Text = owner.DisplayName .. (if isMe then " (you)" else ""),
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 22,
					Parent = card,
				})
				UIKit.label({
					Position = UDim2.fromOffset(14, 34),
					Size = UDim2.new(1, -260, 0, 20),
					Text = ("Plot %d  •  👍 %d  •  🔄 %d"):format(plotId, owner:GetAttribute("Likes") or 0, owner:FindFirstChild("leaderstats") and owner.leaderstats:FindFirstChild("Rebirths") and owner.leaderstats.Rebirths.Value or 0),
					TextColor3 = Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 16,
					Parent = card,
				})
				UIKit.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -128, 0.5, 0),
					Size = UDim2.fromOffset(110, 44),
					Color = Theme.Blue,
					Text = "VISIT",
					Parent = card,
				}, function()
					Net.Fire("VisitPlot", plotId)
				end)
				local trade = UIKit.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(110, 44),
					Color = Theme.Accent,
					Text = "TRADE",
					Parent = card,
				}, function()
					Net.Fire("TradeRequest", owner.UserId)
				end)
				trade.Visible = not isMe
			end
		end
	end

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			update()
		end
	end)
	Players.PlayerAdded:Connect(update)
	Players.PlayerRemoving:Connect(function()
		task.defer(update)
	end)
	update()

	return window
end

return PlayersPanel
