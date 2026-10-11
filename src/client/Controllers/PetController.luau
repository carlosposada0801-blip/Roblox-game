--[[
	PetController
	Draws every player's equipped drone pets (attribute EquippedPets) on
	this client: a hovering body with eyes, a spinning propeller and a
	rarity glow, trailing behind its owner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))

local PetController = {}

local folder
local owners = {} -- [Player] = { Models = { {Model, CFrame} }, Key = string }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function buildPet(petType)
	local info = PetConfig.Pets[petType]
	if not info then
		return nil
	end
	local rarityColor = PetConfig.RarityColors[info.Rarity] or info.Color
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petType

	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Color = info.Color, Material = Enum.Material.SmoothPlastic }, model)
	model.PrimaryPart = body
	part({ Name = "Visor", Size = Vector3.new(1.3, 0.5, 0.3), CFrame = CFrame.new(0, 0.15, -0.8), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.SmoothPlastic }, model)
	for _, x in ipairs({ -0.3, 0.3 }) do
		part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(x, 0.15, -0.95), Color = Color3.fromRGB(0, 255, 255), Material = Enum.Material.Neon }, model)
	end
	part({ Name = "Ring", Size = Vector3.new(2.6, 0.15, 2.6), Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = rarityColor, Material = Enum.Material.Neon, Transparency = 0.3 }, model)
	part({ Name = "Mast", Size = Vector3.new(0.15, 0.5, 0.15), CFrame = CFrame.new(0, 1.1, 0), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Metal }, model)
	local propeller = part({ Name = "Propeller", Size = Vector3.new(2, 0.08, 0.3), CFrame = CFrame.new(0, 1.35, 0), Color = Color3.fromRGB(220, 225, 235), Material = Enum.Material.Metal }, model)
	propeller:SetAttribute("PetSpin", true)

	if info.Rarity ~= "Common" and info.Rarity ~= "Uncommon" then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = body
	end
	if info.Rarity == "Legendary" or info.Rarity == "Mythic" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarityColor
		sparkles.Parent = body
	end

	-- Store each part's offset from the body so we can move the drone as one piece
	local offsets = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			offsets[p] = p.CFrame
		end
	end
	model.Parent = folder
	return { Model = model, Offsets = offsets, CFrame = nil }
end

local function clear(owner)
	local entry = owners[owner]
	if entry then
		for _, pet in ipairs(entry.Pets) do
			pet.Model:Destroy()
		end
		owners[owner] = nil
	end
end

local function rebuild(owner)
	local key = owner:GetAttribute("EquippedPets") or ""
	local entry = owners[owner]
	if entry and entry.Key == key then
		return
	end
	clear(owner)
	local pets = {}
	for petType in string.gmatch(key, "[^,]+") do
		local pet = buildPet(petType)
		if pet then
			table.insert(pets, pet)
		end
	end
	owners[owner] = { Key = key, Pets = pets }
end

local function watch(owner)
	owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(owner)
	end)
	rebuild(owner)
end

function PetController:Start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace

	for _, owner in ipairs(Players:GetPlayers()) do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	local parts, cframes = {}, {}
	RunService.RenderStepped:Connect(function(dt)
		table.clear(parts)
		table.clear(cframes)
		local now = os.clock()
		local alpha = math.min(1, dt * 7)

		for owner, entry in pairs(owners) do
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local count = #entry.Pets
				for index, pet in ipairs(entry.Pets) do
					local side = (index - (count + 1) / 2) * 3
					local bob = math.sin(now * 3 + index) * 0.4
					local target = root.CFrame * CFrame.new(side, 2.2 + bob, 4)
					pet.CFrame = if pet.CFrame then pet.CFrame:Lerp(target, alpha) else target
					for p, offset in pairs(pet.Offsets) do
						local cf = pet.CFrame * offset
						if p:GetAttribute("PetSpin") then
							cf *= CFrame.Angles(0, now * 18, 0)
						end
						table.insert(parts, p)
						table.insert(cframes, cf)
					end
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PetController
