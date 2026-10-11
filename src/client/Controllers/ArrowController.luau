--[[
	ArrowController
	Glowing chevrons that slide along every part tagged "MovingArrows"
	(conveyor belts and the speedy walkway), in the direction and at the
	speed the part moves things. Local-only parts, so no network cost.
	Tagged part attributes: Direction (1 / -1 along its X axis), Speed, Color.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ArrowController = {}

local SPACING = 6
local ARM_ANGLE = math.atan2(2.5, 2)
local ARM_OFFSETS = {
	CFrame.new(-1, 0, -1.25) * CFrame.Angles(0, -ARM_ANGLE, 0),
	CFrame.new(-1, 0, 1.25) * CFrame.Angles(0, ARM_ANGLE, 0),
}

local folder
local tracks = {} -- [BasePart] = { Chevrons = { {arm, arm}, ... }, Scale }

local function makeArm(color, scale)
	local arm = Instance.new("Part")
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false
	arm.CastShadow = false
	arm.Size = Vector3.new(3.2 * scale, 0.06, 0.6 * scale)
	arm.Color = color
	arm.Material = Enum.Material.Neon
	arm.Parent = folder
	return arm
end

local function add(part)
	if tracks[part] or not part:IsA("BasePart") then
		return
	end
	local color = part:GetAttribute("Color") or Color3.new(1, 1, 1)
	local scale = math.min(1, part.Size.Z / 8)
	local chevrons = {}
	for _ = 1, math.max(1, math.floor(part.Size.X / SPACING)) do
		table.insert(chevrons, { makeArm(color, scale), makeArm(color, scale) })
	end
	tracks[part] = { Chevrons = chevrons, Scale = scale }
end

local function remove(part)
	local track = tracks[part]
	if track then
		for _, chevron in ipairs(track.Chevrons) do
			chevron[1]:Destroy()
			chevron[2]:Destroy()
		end
		tracks[part] = nil
	end
end

function ArrowController:Start()
	folder = Instance.new("Folder")
	folder.Name = "MovingArrows"
	folder.Parent = workspace

	for _, part in ipairs(CollectionService:GetTagged("MovingArrows")) do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("MovingArrows"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("MovingArrows"):Connect(remove)

	local parts, cframes = {}, {}
	RunService.RenderStepped:Connect(function()
		table.clear(parts)
		table.clear(cframes)
		local now = workspace:GetServerTimeNow()

		for part, track in pairs(tracks) do
			if not part.Parent then
				remove(part)
				continue
			end
			local direction = part:GetAttribute("Direction") or 1
			local speed = part:GetAttribute("Speed") or 0
			local length = part.Size.X
			local top = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.04, 0)
			local facing = if direction < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			local travelled = now * speed

			for index, chevron in ipairs(track.Chevrons) do
				local along = ((index - 1) * SPACING + travelled) % length - length / 2
				local origin = top * CFrame.new(along * direction, 0, 0) * facing
				for armIndex = 1, 2 do
					local offset = ARM_OFFSETS[armIndex]
					table.insert(parts, chevron[armIndex])
					table.insert(cframes, origin * CFrame.new(offset.Position * track.Scale) * offset.Rotation)
				end
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return ArrowController
