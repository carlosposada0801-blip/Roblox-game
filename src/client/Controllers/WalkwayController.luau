--[[
	WalkwayController
	Draws glowing arrows that slide along each walkway lane in its direction
	of travel. The arrows are local-only parts (other players' clients draw
	their own), so animating them costs no network traffic. The movement
	itself is done by the server: each lane part has a velocity.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SceneryConfig"))

local WalkwayController = {}

local ARM_LENGTH = 3.2
local ARM_ANGLE = math.atan2(2.5, 2)

local function makeArm(color, parent)
	local arm = Instance.new("Part")
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false
	arm.CastShadow = false
	arm.Size = Vector3.new(ARM_LENGTH, 0.06, 0.6)
	arm.Color = color
	arm.Material = Enum.Material.Neon
	arm.Parent = parent
	return arm
end

function WalkwayController:Start()
	local walkway = workspace:WaitForChild("Scenery"):WaitForChild("Walkway")
	local spacing = SceneryConfig.Walkway.ChevronSpacing

	local folder = Instance.new("Folder")
	folder.Name = "WalkwayArrows"
	folder.Parent = workspace

	-- Each chevron ">" is two arms meeting at a tip that points along +X in chevron space
	local armOffsets = {
		CFrame.new(-1, 0, -1.25) * CFrame.Angles(0, -ARM_ANGLE, 0),
		CFrame.new(-1, 0, 1.25) * CFrame.Angles(0, ARM_ANGLE, 0),
	}

	local lanes = {}
	for index = 1, #SceneryConfig.Walkway.Lanes do
		local lane = walkway:WaitForChild("Lane" .. index)
		local length = lane.Size.X
		local entry = {
			Part = lane,
			Direction = lane:GetAttribute("Direction") or 1,
			Speed = lane:GetAttribute("Speed") or 0,
			Length = length,
			Chevrons = {},
		}
		local color = lane:GetAttribute("Color") or Color3.new(1, 1, 1)
		local count = math.floor(length / spacing)
		for i = 0, count - 1 do
			table.insert(entry.Chevrons, {
				Offset = i * spacing,
				Arms = { makeArm(color, folder), makeArm(color, folder) },
			})
		end
		table.insert(lanes, entry)
	end

	local parts, cframes = {}, {}
	RunService.RenderStepped:Connect(function()
		table.clear(parts)
		table.clear(cframes)
		local now = workspace:GetServerTimeNow()

		for _, lane in ipairs(lanes) do
			local top = lane.Part.CFrame * CFrame.new(0, lane.Part.Size.Y / 2 + 0.04, 0)
			local facing = if lane.Direction < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			local travelled = now * lane.Speed

			for _, chevron in ipairs(lane.Chevrons) do
				-- Position along the lane, wrapped so arrows loop forever
				local along = (chevron.Offset + travelled) % lane.Length - lane.Length / 2
				local origin = top * CFrame.new(along * lane.Direction, 0, 0) * facing
				for armIndex, arm in ipairs(chevron.Arms) do
					table.insert(parts, arm)
					table.insert(cframes, origin * armOffsets[armIndex])
				end
			end
		end

		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return WalkwayController
