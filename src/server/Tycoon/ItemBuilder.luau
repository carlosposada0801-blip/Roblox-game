--[[
	ItemBuilder
	Turns an ItemConfig entry into a Model on a plot: either a copy of
	ServerStorage.TycoonItems[<Id>] if you made a custom model, or parts built
	from the entry's Parts list.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ItemBuilder = {}

-- Keys in a part definition that are handled here instead of set as properties
local SPECIAL_KEYS = {
	CFrame = true,
	Light = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
	Emitter = true,
	Spin = true,
	Teleport = true, -- plot-local position: touching this part moves you there (floor lifts)
	Sign = true, -- text floating above the part
}

-- Lift pads: anyone touching the part is moved to the destination
local function hookTeleport(part, destination)
	local last = setmetatable({}, { __mode = "k" }) -- players who left can be garbage collected
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or os.clock() - (last[player] or 0) < 1.5 then
			return
		end
		last[player] = os.clock()
		character:PivotTo(destination)
	end)
end

local function addSign(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(160, 34)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 160)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
	billboard.Parent = part
end

-- Particle textures that ship with Roblox (no uploads needed)
local TEXTURES = {
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local function addEffects(part, definition)
	if definition.Fire then
		local fire = Instance.new("Fire")
		for key, value in pairs(definition.Fire) do
			fire[key] = value
		end
		fire.Parent = part
	end
	if definition.Smoke then
		local smoke = Instance.new("Smoke")
		for key, value in pairs(definition.Smoke) do
			smoke[key] = value
		end
		smoke.Parent = part
	end
	if definition.Sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = definition.Sparkles
		sparkles.Parent = part
	end
	if definition.Emitter then
		local config = definition.Emitter
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = TEXTURES[config.Texture or "Sparkle"] or config.Texture
		emitter.Rate = config.Rate or 10
		emitter.Lifetime = NumberRange.new(config.Lifetime or 0.6, (config.Lifetime or 0.6) * 1.5)
		emitter.Speed = NumberRange.new(config.Speed or 4, (config.Speed or 4) * 2)
		emitter.SpreadAngle = Vector2.new(config.Spread or 40, config.Spread or 40)
		emitter.Size = NumberSequence.new(config.Size or 0.4, 0)
		emitter.LightEmission = config.LightEmission or 0.8
		emitter.Acceleration = config.Acceleration or Vector3.new(0, -10, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		if config.Colors then
			local keypoints = {}
			for index, color in ipairs(config.Colors) do
				table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #config.Colors - 1), color))
			end
			emitter.Color = ColorSequence.new(keypoints)
		end
		emitter.Parent = part
	end
	if definition.Spin then
		-- Clients spin parts with this attribute (radians per second)
		part:SetAttribute("Spin", definition.Spin)
	end
end

local function buildPart(definition, plotCFrame)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(definition) do
		if not SPECIAL_KEYS[key] then
			part[key] = value
		end
	end

	part.CFrame = plotCFrame * (definition.CFrame or CFrame.identity)
	addEffects(part, definition)

	if definition.Light then
		local light = Instance.new("PointLight")
		for key, value in pairs(definition.Light) do
			light[key] = value
		end
		light.Parent = part
	end

	return part
end

local function addLabel(model, text)
	local anchor = model.PrimaryPart
	if not anchor then
		return
	end
	local center, size = model:GetBoundingBox()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.MaxDistance = 120
	billboard.AlwaysOnTop = false
	billboard.Adornee = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	-- Center the label over the whole model, not just the first part
	billboard.StudsOffsetWorldSpace = center.Position - anchor.Position + Vector3.new(0, size.Y / 2 + 2, 0)
	billboard.Parent = anchor
end

-- Builds the item and parents it to the plot's Items folder.
function ItemBuilder.build(item, plot)
	local model
	local templates = ServerStorage:FindFirstChild("TycoonItems")
	local template = templates and templates:FindFirstChild(item.Id)

	if template then
		model = template:Clone()
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		model:PivotTo(plot.CFrame * (item.Pivot or CFrame.identity))
	else
		model = Instance.new("Model")
		for _, definition in ipairs(item.Parts or {}) do
			local part = buildPart(definition, plot.CFrame)
			part.Parent = model
			if definition.Teleport then
				hookTeleport(part, plot.CFrame * CFrame.new(definition.Teleport))
			end
			if definition.Sign then
				addSign(part, definition.Sign)
			end
			if not model.PrimaryPart then
				model.PrimaryPart = part
			end
		end
	end

	model.Name = item.Id
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Category", item.Category)

	if item.Label then
		addLabel(model, item.DisplayName)
	end

	model.Parent = plot.Model.Items
	return model
end

return ItemBuilder
