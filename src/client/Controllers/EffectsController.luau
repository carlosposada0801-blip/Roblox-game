--[[
	EffectsController
	All the "juice", drawn locally on each client:
	  * Fx remote: "Confetti" (world burst or full screen), "Coins", "Upgrade", "Rebirth"
	  * Parts with a Spin attribute rotate (gears, fans, robot arms)
	  * Parts with a Blink attribute flash (warning lights)
	  * Hired worker bots pace and bob while they work
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

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

local workerBases = {} -- [Model] = { Pivot, Phase }

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
						entry = { Pivot = model:GetPivot(), Phase = math.random() * math.pi * 2 }
						workerBases[model] = entry
					end
					local t = now * 1.4 + entry.Phase
					local pace = math.sin(t) * 1.5
					local hop = math.abs(math.sin(t * 4)) * 0.25
					local turn = if math.cos(t) > 0 then math.rad(20) else math.rad(-20)
					model:PivotTo(entry.Pivot * CFrame.new(pace, hop, 0) * CFrame.Angles(0, turn, 0))
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

function EffectsController:Start()
	Net.On("Fx", onFx)

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
