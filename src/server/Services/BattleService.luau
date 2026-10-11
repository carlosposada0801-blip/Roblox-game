--[[
	BattleService
	Robot Battle Arena (BattleConfig): 1v1 stat-based Prototype fights.
	  * BattleAction("Queue" | "Leave") or the ring terminal's prompt joins/leaves the queue.
	  * A matchmaking loop pairs the first two queued players. One battle runs
	    at a time; everyone in the lobby can watch it in the ring.
	  * Fights are decided entirely on the server: alternating attacks with
	    random damage, crits and dodges. Robots lunge, flash and show health
	    bars; both players get BattleState updates for their screen.
	  * Winner: cash + data.BattleWins (ranked board). Loser: consolation cash +
	    data.BattleLosses. Leaving mid-fight forfeits.
	  * Alone in the queue for PracticeWait seconds: fight a Training Bot for
	    a smaller, unranked reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleConfig = require(Shared.Config.BattleConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlayerService, QuestService, Net

local BattleService = {}

local queue = {} -- list of { Player, Since }
local current -- running battle or nil
local folder, ringCenter, terminal

-- Stats ------------------------------------------------------------------------------

function BattleService:GetStats(player: Player)
	local data = DataService:GetData(player)
	local stats = BattleConfig.Stats
	local prototypes = data and data.Prototypes or 0
	local rebirths = data and data.Rebirths or 0
	local bonus = math.min(stats.MaxBonus, math.max(0, prototypes - 1) * stats.PerExtraPrototype + rebirths * stats.PerRebirth)
	return {
		Health = math.floor(stats.Health * (1 + bonus)),
		Attack = math.floor(stats.Attack * (1 + bonus) * 10) / 10,
		Bonus = bonus,
	}
end

-- Building ---------------------------------------------------------------------------

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function billboard(parent, size, offset, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return gui
end

local function buildRing()
	folder = Instance.new("Folder")
	folder.Name = "BattleArena"
	folder.Parent = workspace
	ringCenter = BattleConfig.Ring
	local radius = BattleConfig.RingRadius
	local purple = Color3.fromRGB(170, 60, 255)

	local floor = part({ Name = "RingFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, radius * 2, radius * 2), CFrame = CFrame.new(ringCenter + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.DiamondPlate }, folder)
	part({ Name = "RingEdge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, radius * 2 + 1.5, radius * 2 + 1.5), CFrame = floor.CFrame * CFrame.new(-0.02, 0, 0), Color = purple, Material = Enum.Material.Neon, CanCollide = false }, folder)
	-- Corner posts with lights
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local post = part({ Name = "Post", Size = Vector3.new(1.2, 8, 1.2), CFrame = CFrame.new(ringCenter + Vector3.new(math.cos(angle) * radius, 4.5, math.sin(angle) * radius)), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal }, folder)
		local lamp = part({ Name = "PostLight", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = post.CFrame * CFrame.new(0, 4.6, 0), Color = purple, Material = Enum.Material.Neon }, folder)
		local light = Instance.new("PointLight")
		light.Color = purple
		light.Range = 18
		light.Parent = lamp
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = CFrame.new(ringCenter + Vector3.new(0, 16, 0)) }, folder)
	billboard(sign, UDim2.fromOffset(360, 70), Vector3.new(), "🥊 ROBOT BATTLE ARENA", Color3.fromRGB(255, 200, 60))
	local status = billboard(sign, UDim2.fromOffset(360, 36), Vector3.new(0, -3.2, 0), "Queue in the Battle menu!", Color3.new(1, 1, 1))
	status.Name = "Status"

	-- Terminal: join the queue with a prompt too
	terminal = part({ Name = "Terminal", Size = Vector3.new(3, 4, 2), CFrame = CFrame.new(ringCenter + Vector3.new(radius + 4, 2, 0)), Color = Color3.fromRGB(40, 42, 55), Material = Enum.Material.Metal }, folder)
	part({ Name = "Screen", Size = Vector3.new(2.4, 2, 0.2), CFrame = terminal.CFrame * CFrame.new(0, 0.6, -1.05), Color = purple, Material = Enum.Material.Neon }, folder)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueuePrompt"
	prompt.ActionText = "Join / leave the battle queue"
	prompt.ObjectText = "Robot Battle"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Enabled = true
	prompt.Parent = terminal
	return prompt
end

local function setStatus(text)
	local sign = folder:FindFirstChild("Sign")
	local status = sign and sign:FindFirstChild("Status")
	if status then
		status.Text.Text = text
	end
end

local function buildFighter(name, color, cframe, isPrototype)
	local model = Instance.new("Model")
	model.Name = "Fighter"
	local function piece(pieceName, size, offset, pieceColor, material)
		return part({ Name = pieceName, Size = size, CFrame = cframe * offset, Color = pieceColor, Material = material or Enum.Material.Metal, CanCollide = false }, model)
	end
	local body = piece("Body", Vector3.new(3, 3.4, 2.2), CFrame.new(0, 4.2, 0), color, Enum.Material.Neon)
	model.PrimaryPart = body
	piece("Legs", Vector3.new(2.2, 2, 1.6), CFrame.new(0, 1.8, 0), Color3.fromRGB(50, 52, 60))
	piece("Head", Vector3.new(2.2, 1.8, 1.8), CFrame.new(0, 6.8, 0), Color3.fromRGB(200, 205, 215))
	piece("Eyes", Vector3.new(1.6, 0.4, 0.1), CFrame.new(0, 6.9, -0.95), Color3.fromRGB(255, 60, 255), Enum.Material.Neon)
	piece("ArmL", Vector3.new(0.9, 2.8, 0.9), CFrame.new(-2, 4.3, 0), Color3.fromRGB(80, 220, 255))
	piece("ArmR", Vector3.new(0.9, 2.8, 0.9), CFrame.new(2, 4.3, 0), Color3.fromRGB(80, 220, 255))
	if isPrototype then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = body
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Brightness = 2
		light.Parent = body
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.fromOffset(180, 46)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Sarpanch
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = name
	nameLabel.Parent = gui
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0, 0.58)
	bar.Size = UDim2.fromScale(1, 0.36)
	bar.BackgroundColor3 = Color3.fromRGB(40, 20, 30)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = body
	model.Parent = folder
	return model, fill
end

-- State for clients -------------------------------------------------------------------

local function queuePosition(player)
	for index, entry in ipairs(queue) do
		if entry.Player == player then
			return index
		end
	end
	return nil
end

local function sendState(player)
	if not player.Parent then
		return
	end
	local state = { Phase = "Idle", Stats = BattleService:GetStats(player) }
	local position = queuePosition(player)
	if current and (current.A.Player == player or current.B.Player == player) then
		local me = if current.A.Player == player then current.A else current.B
		local them = if me == current.A then current.B else current.A
		state.Phase = "Fighting"
		state.Opponent = them.Name
		state.MyHealth = math.max(0, math.floor(me.Health))
		state.MyMax = me.Max
		state.TheirHealth = math.max(0, math.floor(them.Health))
		state.TheirMax = them.Max
		state.Log = current.LastLog
	elseif position then
		state.Phase = "Queued"
		state.Position = position
		state.Waiting = #queue
	end
	Net:Fire(player, "BattleState", state)
end

local function sendAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") then
			sendState(player)
		end
	end
	if current then
		setStatus(("%s  VS  %s"):format(current.A.Name, current.B.Name))
	elseif #queue > 0 then
		setStatus(("%d waiting for a match..."):format(#queue))
	else
		setStatus("Queue in the Battle menu!")
	end
end

-- Queue -------------------------------------------------------------------------------

local function leaveQueue(player)
	local position = queuePosition(player)
	if position then
		table.remove(queue, position)
	end
end

local function joinQueue(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if data.Prototypes < BattleConfig.MinPrototypes then
		Net:Notify(player, "You need a ⭐ Prototype robot to battle. Every robot has a small chance to become one!", "error")
		return
	end
	if queuePosition(player) or (current and (current.A.Player == player or current.B.Player == player)) then
		return
	end
	table.insert(queue, { Player = player, Since = os.clock() })
	Net:Notify(player, "🥊 You joined the battle queue!", "info")
	sendAll()
end

-- Fighting -----------------------------------------------------------------------------

local function lunge(fighter, towards)
	local model = fighter.Model
	if not model.Parent then
		return
	end
	local home = fighter.Home
	local forward = (towards - home.Position) * Vector3.new(1, 0, 1)
	local value = Instance.new("CFrameValue")
	value.Value = home
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local out = TweenService:Create(value, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = home + forward.Unit * 3.5 })
	out:Play()
	out.Completed:Once(function()
		TweenService:Create(value, TweenInfo.new(0.25), { Value = home }):Play()
		task.delay(0.3, value.Destroy, value)
	end)
end

local function flashHit(fighter)
	local body = fighter.Model.PrimaryPart
	if body then
		local original = body.Color
		body.Color = Color3.new(1, 1, 1)
		task.delay(0.12, function()
			if body.Parent then
				body.Color = original
			end
		end)
	end
end

local function updateBars()
	for _, fighter in ipairs({ current.A, current.B }) do
		local fraction = math.clamp(fighter.Health / fighter.Max, 0, 1)
		fighter.Fill.Size = UDim2.fromScale(fraction, 1)
		fighter.Fill.BackgroundColor3 = if fraction > 0.5 then Color3.fromRGB(80, 230, 110) elseif fraction > 0.25 then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(255, 60, 60)
	end
end

local function makeFighter(player, side)
	local stats = if player then BattleService:GetStats(player) else BattleConfig.TrainingBot
	local name = if player then player.DisplayName .. "'s Prototype" else BattleConfig.TrainingBot.Name
	local offset = Vector3.new(side * 6, 0.7 + 0.7, 0)
	local home = CFrame.lookAt(ringCenter + offset, ringCenter + Vector3.new(0, offset.Y, 0))
	local color = if player then (if side < 0 then Color3.fromRGB(150, 60, 255) else Color3.fromRGB(255, 80, 120)) else Color3.fromRGB(120, 120, 130)
	local model, fill = buildFighter(name, color, home, player ~= nil)
	-- Home is the model's pivot (its body), which is what lunges move
	return { Player = player, Name = if player then player.DisplayName else stats.Name, Health = stats.Health, Max = stats.Health, Attack = stats.Attack, Model = model, Fill = fill, Home = model:GetPivot() }
end

local function payout(player, cash, won, ranked)
	local data = player and player.Parent and DataService:GetData(player)
	if not data then
		return
	end
	local amount = cash * RebirthConfig.GetMultiplier(data.Rebirths)
	EconomyService:AddCash(player, amount)
	if ranked then
		EconomyService:AddStat(player, if won then "BattleWins" else "BattleLosses", 1)
	end
	if won then
		QuestService:Track(player, "BattleWins", 1)
		Net:Fire(player, "Fx", "Confetti")
		Net:Fire(player, "Sfx", "Rebirth")
		Net:Notify(player, "🏆 Your Prototype WON the battle! +" .. Format.cash(amount), "special")
	else
		Net:Notify(player, "Your Prototype lost this time. +" .. Format.cash(amount) .. " for trying!", "info")
	end
end

local function finish(battle, winner, loser, reason)
	if current ~= battle then
		return
	end
	current = nil
	local ranked = battle.A.Player ~= nil and battle.B.Player ~= nil
	local rewards = BattleConfig.Rewards
	if winner.Player then
		payout(winner.Player, if ranked then rewards.WinCash else rewards.PracticeWinCash, true, ranked)
	end
	if loser.Player and loser.Player.Parent and reason ~= "Forfeit" then
		payout(loser.Player, if ranked then rewards.LoseCash else 0, false, ranked)
	elseif loser.Player and reason == "Forfeit" then
		local data = DataService:GetData(loser.Player)
		if data and ranked then
			EconomyService:AddStat(loser.Player, "BattleLosses", 1)
		end
	end
	if ranked then
		Net:NotifyAll(("🥊 %s's Prototype beat %s's in the Battle Arena!"):format(winner.Name, loser.Name), "info")
	end
	-- Loser falls over, winner celebrates, then both disappear
	if loser.Model.Parent then
		loser.Model:PivotTo(loser.Home * CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(80), 0, 0))
	end
	task.delay(3, function()
		battle.A.Model:Destroy()
		battle.B.Model:Destroy()
		sendAll()
	end)
	for _, fighter in ipairs({ battle.A, battle.B }) do
		if fighter.Player and fighter.Player.Parent then
			Net:Fire(fighter.Player, "BattleState", {
				Phase = "Result",
				Won = fighter == winner,
				Opponent = if fighter == winner then loser.Name else winner.Name,
				Stats = BattleService:GetStats(fighter.Player),
			})
		end
	end
	setStatus(("🏆 %s WINS!"):format(winner.Name))
end

local function startBattle(playerA, playerB)
	local battle = { Turn = 0, LastLog = "" }
	battle.A = makeFighter(playerA, -1)
	battle.B = makeFighter(playerB, 1)
	current = battle
	updateBars()

	-- Move the players to the ring side so they can watch
	for index, player in ipairs({ playerA, playerB }) do
		local character = player and player.Character
		if character and not player:GetAttribute("InArena") then
			local spot = ringCenter + Vector3.new(0, 3, (if index == 1 then -1 else 1) * (BattleConfig.RingRadius + 6))
			pcall(player.RequestStreamAroundAsync, player, spot, 3)
			character:PivotTo(CFrame.lookAt(spot, ringCenter + Vector3.new(0, 3, 0)))
		end
	end
	sendAll()

	task.spawn(function()
		for count = BattleConfig.CountdownSeconds, 1, -1 do
			if current ~= battle then
				return
			end
			battle.LastLog = ("Fight starts in %d..."):format(count)
			setStatus(battle.LastLog)
			for _, fighter in ipairs({ battle.A, battle.B }) do
				if fighter.Player then
					Net:Fire(fighter.Player, "Sfx", "Tick")
					sendState(fighter.Player)
				end
			end
			task.wait(1)
		end
		local stats = BattleConfig.Stats
		local attacker, defender = battle.A, battle.B
		if math.random() < 0.5 then
			attacker, defender = defender, attacker
		end
		while current == battle and battle.Turn < BattleConfig.MaxTurns do
			battle.Turn += 1
			lunge(attacker, defender.Home.Position)
			task.wait(0.18)
			if current ~= battle then
				return
			end
			if math.random() < stats.DodgeChance then
				battle.LastLog = defender.Name .. " dodged!"
			else
				local damage = attacker.Attack * (0.8 + math.random() * 0.4)
				local crit = math.random() < stats.CritChance
				if crit then
					damage *= stats.CritMultiplier
				end
				damage = math.floor(damage + 0.5)
				defender.Health -= damage
				flashHit(defender)
				battle.LastLog = ("%s hits for %d%s"):format(attacker.Name, damage, if crit then " (CRIT!)" else "")
			end
			updateBars()
			for _, fighter in ipairs({ battle.A, battle.B }) do
				if fighter.Player then
					sendState(fighter.Player)
				end
			end
			if defender.Health <= 0 then
				finish(battle, attacker, defender, "KO")
				return
			end
			attacker, defender = defender, attacker
			task.wait(BattleConfig.TurnTime)
		end
		if current == battle then
			-- Time's up: more health left (as a share of max) wins
			local a, b = battle.A, battle.B
			if a.Health / a.Max >= b.Health / b.Max then
				finish(battle, a, b, "Time")
			else
				finish(battle, b, a, "Time")
			end
		end
	end)
end

local function matchmake()
	if current then
		return
	end
	-- Drop anyone who left
	for index = #queue, 1, -1 do
		if not queue[index].Player.Parent then
			table.remove(queue, index)
		end
	end
	if #queue >= 2 then
		local a = table.remove(queue, 1)
		local b = table.remove(queue, 1)
		startBattle(a.Player, b.Player)
	elseif #queue == 1 and os.clock() - queue[1].Since >= BattleConfig.PracticeWait then
		local a = table.remove(queue, 1)
		Net:Notify(a.Player, "No opponent yet, so here's a Training Bot! (unranked)", "info")
		startBattle(a.Player, nil)
	end
end

local function action(player, kind)
	if kind == "Queue" then
		if queuePosition(player) then
			leaveQueue(player)
			sendAll()
		else
			joinQueue(player)
		end
	elseif kind == "Leave" then
		leaveQueue(player)
		sendAll()
	end
end

function BattleService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	Net = services.Net
end

function BattleService:Start()
	local prompt = buildRing()
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("DataLoaded") then
			action(player, "Queue")
		end
	end)
	Net:On("BattleAction", action, 2, 3)
	PlayerService.PlayerReady:Connect(sendState)
	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
		if current then
			if current.A.Player == player then
				finish(current, current.B, current.A, "Forfeit")
			elseif current.B.Player == player then
				finish(current, current.A, current.B, "Forfeit")
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			matchmake()
		end
	end)
end

-- Studio testing: start a battle right away
function BattleService:DevStart(playerA: Player, playerB: Player?)
	leaveQueue(playerA)
	if playerB then
		leaveQueue(playerB)
	end
	if not current then
		startBattle(playerA, playerB)
	end
end

function BattleService:IsBusy(): boolean
	return current ~= nil
end

return BattleService
