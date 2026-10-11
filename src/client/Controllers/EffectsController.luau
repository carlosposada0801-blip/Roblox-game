--[[
	EffectsController
	All the "juice", drawn locally on each client:
	  * Fx remote: "Confetti" (world burst or full screen), "Coins", "Upgrade", "Rebirth"
	  * Parts with a Spin attribute rotate (gears, fans, robot arms)
	  * Parts with a Blink attribute flash (warning lights)
	  * Hired worker bots pace and bob while they work
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local player = Players.LocalPlayer

local EffectsController = {}

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(60, 220, 110),
	Color3.fromRGB(0, 190, 255),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 100, 200),
}

-- World particle burst at a position
local function burst(position, colors, count, texture, speed)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local keypoints = {}
	for index, color in ipairs(colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(speed, speed * 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.6, 0.2)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.LightEmission = 0.5
	emitter.Color = ColorSequence.new(keypoints)
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 3)
end

-- Paper confetti falling over the whole screen
local function screenConfetti()
	local root = UIKit.root()
	for _ = 1, 70 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.Position = UDim2.new(math.random(), 0, 0, -30)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 90
		piece.Parent = root
		local duration = math.random(18, 32) / 10
		local tween = TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		})
		tween:Play()
		Debris:AddItem(piece, duration + 0.1)
	end
end

local function flash()
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.1
	frame.ZIndex = 95
	frame.Parent = UIKit.root()
	TweenService:Create(frame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.9)
end

local function shake(duration, strength)
	if player:GetAttribute("Setting_ScreenShake") == false then
		return -- Settings > Screen Shake
	end
	local camera = workspace.CurrentCamera
	local ends = os.clock() + duration
	local name = "Shake" .. tostring(os.clock())
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local remaining = ends - os.clock()
		if remaining <= 0 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local power = strength * remaining / duration
		camera.CFrame *= CFrame.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, 0)
	end)
end

local function onFx(kind, position, ...)
	if kind == "Confetti" then
		if typeof(position) == "Vector3" then
			burst(position, CONFETTI_COLORS, 70, "rbxasset://textures/particles/SquareParticle.png", 18)
		else
			screenConfetti()
		end
	elseif kind == "Coins" and typeof(position) == "Vector3" then
		burst(position + Vector3.new(0, 1, 0), { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 170, 20) }, 30, "rbxasset://textures/particles/sparkles_main.dds", 12)
	elseif kind == "Upgrade" and typeof(position) == "Vector3" then
		burst(position, { Color3.fromRGB(0, 230, 255), Color3.fromRGB(255, 255, 255) }, 50, "rbxasset://textures/particles/sparkles_main.dds", 14)
	elseif kind == "Shot" and typeof(position) == "Vector3" then
		local target, color = ...
		if typeof(target) ~= "Vector3" then
			return
		end
		local distance = (target - position).Magnitude
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = if typeof(color) == "Color3" then color else Color3.new(1, 0.2, 0.2)
		beam.Size = Vector3.new(0.25, 0.25, distance)
		beam.CFrame = CFrame.lookAt(position, target) * CFrame.new(0, 0, -distance / 2)
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 0.2)
		burst(target, { beam.Color, Color3.new(1, 1, 1) }, 8, "rbxasset://textures/particles/sparkles_main.dds", 6)
	elseif kind == "Rebirth" then
		flash()
		shake(0.8, 1.5)
		screenConfetti()
	elseif kind == "BigSale" and typeof(position) == "Vector3" then
		burst(position + Vector3.new(0, 1, 0), CONFETTI_COLORS, 60, "rbxasset://textures/particles/SquareParticle.png", 16)
		burst(position + Vector3.new(0, 1, 0), { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 170, 20) }, 30, "rbxasset://textures/particles/sparkles_main.dds", 12)
		shake(0.35, 0.6)
	elseif kind == "Shake" then
		shake(tonumber(position) or 0.5, 1)
	end
end

-- Spinning and blinking parts --------------------------------------------------------

local spinners = {} -- [BasePart] = { Base = CFrame, Speed = number }
local blinkers = {} -- [BasePart] = baseTransparency

local function register(instance)
	if not instance:IsA("BasePart") then
		return
	end
	local spin = instance:GetAttribute("Spin")
	if type(spin) == "number" then
		spinners[instance] = { Base = instance.CFrame, Speed = spin }
	end
	if instance:GetAttribute("Blink") then
		blinkers[instance] = instance.Transparency
	end
end

local function unregister(instance)
	spinners[instance] = nil
	blinkers[instance] = nil
end

-- Worker bots ------------------------------------------------------------------

local workerBases = {} -- [Model] = { Pivot, Phase, Target? }

-- Bots with a WorkTarget walk there, work for a moment, and walk back home.
-- Bots without one pace near their slot. One trip = WALK + WORK + WALK + REST seconds.
local WALK, WORK, REST = 4, 2.5, 1.5
local TRIP = WALK * 2 + WORK + REST

local function workerPose(entry, now)
	local home = entry.Pivot
	if not entry.Target then
		local t = now * 1.4 + entry.Phase
		local turn = if math.cos(t) > 0 then math.rad(20) else math.rad(-20)
		return home * CFrame.new(math.sin(t) * 1.5, math.abs(math.sin(t * 4)) * 0.25, 0) * CFrame.Angles(0, turn, 0)
	end
	local target = Vector3.new(entry.Target.X, home.Y, entry.Target.Z)
	if (target - home.Position).Magnitude < 1 then
		return home
	end
	local t = (now + entry.Phase * TRIP / (math.pi * 2)) % TRIP
	local walkBob = math.abs(math.sin(now * 9)) * 0.3
	if t < WALK then
		local position = home.Position:Lerp(target, t / WALK)
		return CFrame.lookAt(position, target) * CFrame.new(0, walkBob, 0)
	elseif t < WALK + WORK then
		-- Working: hop and wiggle at the machine
		local w = t - WALK
		return CFrame.lookAt(target, target + (target - home.Position)) * CFrame.new(0, math.abs(math.sin(w * 8)) * 0.6, 0) * CFrame.Angles(0, math.sin(w * 12) * 0.4, 0)
	elseif t < WALK * 2 + WORK then
		local position = target:Lerp(home.Position, (t - WALK - WORK) / WALK)
		return CFrame.lookAt(position, home.Position) * CFrame.new(0, walkBob, 0)
	end
	return home
end

local function animateWorkers(now)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local workers = plot:FindFirstChild("Workers")
		if workers then
			for _, model in ipairs(workers:GetChildren()) do
				if model:IsA("Model") and model.PrimaryPart then
					local entry = workerBases[model]
					if not entry then
						local target = model:GetAttribute("WorkTarget")
						entry = {
							Pivot = model:GetPivot(),
							Phase = math.random() * math.pi * 2,
							Target = if typeof(target) == "Vector3" then target else nil,
						}
						workerBases[model] = entry
					end
					model:PivotTo(workerPose(entry, now))
				end
			end
		end
	end
	for model in pairs(workerBases) do
		if not model.Parent then
			workerBases[model] = nil
		end
	end
end

-- Floating "+$X" numbers over your collector as cash is earned ------------------------

local function floatingCash(amount)
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plotId and plots and plots:FindFirstChild("Plot" .. plotId)
	local intake = plot and plot:FindFirstChild("Items") and plot.Items:FindFirstChild("Intake", true)
	if not intake then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = intake.CFrame * CFrame.new((math.random() - 0.5) * 3, 3, 0)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.TextStrokeTransparency = 0.3
	label.Text = "+" .. Format.cash(amount)
	label.Parent = billboard

	TweenService:Create(billboard, TweenInfo.new(1.2), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.3)
end

-- Adds up earnings and shows at most one number every 0.4 s (no spam, no lag)
local function watchEarnings()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local pending = 0
	local lastPending = player:GetAttribute("PendingCash") or 0
	player:GetAttributeChangedSignal("PendingCash"):Connect(function()
		local now = player:GetAttribute("PendingCash") or 0
		if now > lastPending then
			pending += now - lastPending
		end
		lastPending = now
	end)
	-- With Auto-Collect, earnings go straight to cash
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local lastCash = cash.Value
	cash.Changed:Connect(function(value)
		if player:GetAttribute("Pass_AutoCollect") and value > lastCash then
			pending += value - lastCash
		end
		lastCash = value
	end)
	while true do
		task.wait(0.4)
		if pending >= 1 then
			floatingCash(pending)
			pending = 0
		end
	end
end

function EffectsController:Start()
	Net.On("Fx", onFx)
	task.spawn(watchEarnings)

	for _, descendant in ipairs(workspace:GetDescendants()) do
		register(descendant)
	end
	workspace.DescendantAdded:Connect(function(descendant)
		-- Attributes may arrive a moment after the part itself
		task.defer(register, descendant)
	end)
	workspace.DescendantRemoving:Connect(unregister)

	local parts, cframes = {}, {}
	local lastBlink = -1
	RunService.RenderStepped:Connect(function()
		local now = os.clock()

		table.clear(parts)
		table.clear(cframes)
		for part, entry in pairs(spinners) do
			table.insert(parts, part)
			table.insert(cframes, entry.Base * CFrame.Angles(0, now * entry.Speed, 0))
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end

		local blinkOn = math.floor(now * 1.6) % 2 == 0
		if blinkOn ~= (lastBlink == 1) then
			lastBlink = if blinkOn then 1 else 0
			for part, base in pairs(blinkers) do
				part.Transparency = if blinkOn then base else 0.8
			end
		end

		animateWorkers(now)
	end)
end

return EffectsController
