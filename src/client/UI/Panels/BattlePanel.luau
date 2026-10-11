--[[
	BattlePanel
	Robot Battle Arena: shows your Prototype's battle stats, your record,
	the queue, and the live fight (health bars). Queue/Leave send
	BattleAction; the server runs the whole fight (BattleService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BattleConfig"))
local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local BattlePanel = {}

function BattlePanel.build()
	local window, content = UIKit.window("🥊 ROBOT BATTLE", Theme.Purple, Vector2.new(560, 470))

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		MaxTextSize = 15,
		Text = "Send your ⭐ Prototype into the ring at the end of the lobby for a 1v1 fight. More Prototypes and rebirths = a stronger fighter!",
		Parent = content,
	})

	local statsCard = UIKit.card({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 70), Parent = content }, Theme.Purple)
	local statsLabel = UIKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = statsCard })
	local recordLabel = UIKit.label({ Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.SubText, MaxTextSize = 17, Parent = statsCard })

	local fightCard = UIKit.card({ Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 170), Parent = content }, Theme.PanelLight)
	local phaseLabel = UIKit.label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 30), Font = Theme.Title, MaxTextSize = 24, Parent = fightCard })
	local myBar, setMine = UIKit.progressBar({ Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 28) }, Theme.Green)
	myBar.Parent = fightCard
	local theirBar, setTheirs = UIKit.progressBar({ Position = UDim2.fromOffset(10, 84), Size = UDim2.new(1, -20, 0, 28) }, Theme.Red)
	theirBar.Parent = fightCard
	local logLabel = UIKit.label({ Position = UDim2.fromOffset(10, 122), Size = UDim2.new(1, -20, 0, 36), TextWrapped = true, TextColor3 = Theme.Accent, MaxTextSize = 18, Parent = fightCard })

	local queueButton = UIKit.button({
		Name = "Queue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.7, 0, 0, 56),
		Color = Theme.Purple,
		Text = "JOIN QUEUE",
		Parent = content,
	}, function()
		Net.Fire("BattleAction", "Queue")
	end)

	local state: any = { Phase = "Idle" }
	local function update()
		local stats = state.Stats or {}
		statsLabel.Text = ("⭐ Your fighter:  ❤️ %d   ⚔️ %s   (+%d%%)"):format(stats.Health or BattleConfig.Stats.Health, tostring(stats.Attack or BattleConfig.Stats.Attack), math.floor((stats.Bonus or 0) * 100 + 0.5))
		recordLabel.Text = ("Record: %d wins / %d losses   •   Prototypes: %d"):format(
			player:GetAttribute("BattleWins") or 0,
			player:GetAttribute("BattleLosses") or 0,
			player:GetAttribute("Prototypes") or 0
		)
		local fighting = state.Phase == "Fighting"
		myBar.Visible = fighting
		theirBar.Visible = fighting
		if fighting then
			phaseLabel.Text = "VS " .. tostring(state.Opponent)
			setMine((state.MyHealth or 0) / math.max(1, state.MyMax or 1), ("You  ❤️ %d / %d"):format(state.MyHealth or 0, state.MyMax or 0))
			setTheirs((state.TheirHealth or 0) / math.max(1, state.TheirMax or 1), ("%s  ❤️ %d / %d"):format(tostring(state.Opponent), state.TheirHealth or 0, state.TheirMax or 0))
			logLabel.Text = state.Log or ""
			queueButton.Text = "FIGHTING..."
			queueButton:SetAttribute("Disabled", true)
		elseif state.Phase == "Queued" then
			phaseLabel.Text = ("In queue: #%d of %d"):format(state.Position or 1, state.Waiting or 1)
			logLabel.Text = "Waiting for an opponent... (a Training Bot steps in if nobody comes)"
			queueButton.Text = "LEAVE QUEUE"
			queueButton:SetAttribute("Disabled", false)
		else
			if state.Phase == "Result" then
				phaseLabel.Text = if state.Won then "🏆 YOU WON!" else "💥 YOU LOST"
				logLabel.Text = "vs " .. tostring(state.Opponent) .. ". Queue again for another round!"
			else
				phaseLabel.Text = "Not in a battle"
				logLabel.Text = ""
			end
			local hasPrototype = (player:GetAttribute("Prototypes") or 0) >= BattleConfig.MinPrototypes
			queueButton.Text = if hasPrototype then "JOIN QUEUE" else "NEED A ⭐ PROTOTYPE"
			queueButton:SetAttribute("Disabled", not hasPrototype)
		end
	end

	Net.On("BattleState", function(newState)
		if type(newState) == "table" then
			state = newState
			update()
			-- Pop the window open when a fight starts
			if state.Phase == "Fighting" and not window.Visible then
				UIKit.open(window)
			end
		end
	end)
	for _, attribute in ipairs({ "BattleWins", "BattleLosses", "Prototypes" }) do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()
	return window
end

return BattlePanel
