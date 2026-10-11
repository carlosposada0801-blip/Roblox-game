--[[
	CustomizationService
	Factory customization (CustomConfig): wall paint, machine paint, floor
	material, a neon sign with your own text, and decorations on fixed slots.
	Some are free, some cost cash, some are VIP (Roblox Premium or the VIP
	Floor pass). Saved in data.Custom / data.OwnedCustom and rebuilt on join,
	after rebirths and whenever a new item is built.

	Remote CustomAction(action, a, b):
	  "Buy", id                 buy a cash item
	  "Equip", category, id     category = "Wall" | "Machine" | "Floor"; id "" = default
	  "Decor", slot, id         put a decoration on a slot; id "" = empty
	  "Sign", text              set the neon sign ("" removes it). Filtered with TextService.
	Attributes: Custom_<category>, Custom_Decor<slot>, Custom_Sign, OwnsCustom_<id>
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomConfig = require(Shared.Config.CustomConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlotService, PlayerService, TycoonService, Net

local CustomizationService = {}

local byId = {}
local CATEGORIES = { Wall = CustomConfig.Walls, Machine = CustomConfig.Machines, Floor = CustomConfig.Floors }
for category, list in pairs(CATEGORIES) do
	for _, entry in ipairs(list) do
		byId[entry.Id] = { Category = category, Item = entry }
	end
end
for _, entry in ipairs(CustomConfig.Decor) do
	byId[entry.Id] = { Category = "Decor", Item = entry }
end

local filteredSigns = {} -- [Player] = text shown to everyone (already filtered)
local lastSign = {} -- [Player] = os.clock(), text filtering is rate limited by Roblox
local SIGN_COOLDOWN = 4

-- Ownership ------------------------------------------------------------------------

local function isVIP(player)
	return player.MembershipType == Enum.MembershipType.Premium or player:GetAttribute("Pass_VIPFloor") == true
end

local function owns(player, id)
	local data = DataService:GetData(player)
	local entry = byId[id]
	if not (data and entry) then
		return false
	end
	if entry.Item.VIP then
		return isVIP(player)
	end
	return (entry.Item.Price or 0) == 0 or data.OwnedCustom[id] == true
end

-- Applying -------------------------------------------------------------------------

-- Remembers a part's original look so "default" can restore it
local function remember(part)
	if part:GetAttribute("OrigColor") == nil then
		part:SetAttribute("OrigColor", part.Color)
		part:SetAttribute("OrigMaterial", part.Material.Name)
	end
end

local function paint(part, color, material)
	remember(part)
	part.Color = color or part:GetAttribute("OrigColor")
	local materialName = if material then material.Name else part:GetAttribute("OrigMaterial")
	local ok, value = pcall(function()
		return Enum.Material[materialName]
	end)
	if ok and value then
		part.Material = value
	end
end

local MACHINE_PARTS = { Roof = true, Pillar = true }

local function applyPaint(player, plot)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local wall = byId[data.Custom.Wall]
	local machine = byId[data.Custom.Machine]
	local floor = byId[data.Custom.Floor]
	for _, model in ipairs(plot.Model.Items:GetChildren()) do
		local item = TycoonService:GetItem(model.Name)
		if item then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon and part.Transparency < 1 then
					if item.Category == "Wall" and part.Material ~= Enum.Material.Glass then
						paint(part, wall and wall.Item.Color)
					elseif item.Category == "Floor" and part.Size.Y <= 2 and part.Size.X >= 20 then
						paint(part, floor and floor.Item.Color, floor and floor.Item.Material)
					elseif item.Machine and MACHINE_PARTS[part.Name] then
						paint(part, machine and machine.Item.Color)
					end
				end
			end
		end
	end
end

-- Decorations (built from parts so no uploads are needed)
local function decorPart(model, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = model
	return part
end

local function buildDecor(kind, base)
	local model = Instance.new("Model")
	model.Name = "Decor_" .. kind
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	if kind == "Plant" then
		decorPart(model, { Size = Vector3.new(2.4, 2, 2.4), CFrame = at(0, 1, 0), Color = Color3.fromRGB(150, 80, 40), Material = Enum.Material.Slate })
		for _, offset in ipairs({ Vector3.new(0, 3.2, 0), Vector3.new(0.8, 2.6, 0.5), Vector3.new(-0.7, 2.7, -0.4) }) do
			decorPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = at(offset.X, offset.Y, offset.Z), Color = Color3.fromRGB(60, 170, 70), Material = Enum.Material.Grass })
		end
	elseif kind == "Crates" then
		decorPart(model, { Size = Vector3.new(3, 3, 3), CFrame = at(0, 1.5, 0), Color = Color3.fromRGB(160, 110, 60), Material = Enum.Material.WoodPlanks })
		decorPart(model, { Size = Vector3.new(2.6, 2.6, 2.6), CFrame = at(0.2, 4.3, 0) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(140, 95, 50), Material = Enum.Material.WoodPlanks })
	elseif kind == "Flag" then
		decorPart(model, { Size = Vector3.new(0.5, 12, 0.5), CFrame = at(0, 6, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal })
		decorPart(model, { Size = Vector3.new(5, 3, 0.2), CFrame = at(2.7, 10.3, 0), Color = Color3.fromRGB(255, 170, 0), Material = Enum.Material.Fabric })
	elseif kind == "LavaLamp" then
		decorPart(model, { Size = Vector3.new(2, 1, 2), CFrame = at(0, 0.5, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
		local glass = decorPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6), CFrame = at(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 80, 40), Material = Enum.Material.Neon, Transparency = 0.2 })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 100, 40)
		light.Range = 10
		light.Parent = glass
	elseif kind == "Fountain" then
		decorPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 6, 6), CFrame = at(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 85, 95), Material = Enum.Material.Concrete })
		local water = decorPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5, 5), CFrame = at(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
		local jet = Instance.new("ParticleEmitter")
		jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		jet.Rate = 30
		jet.Speed = NumberRange.new(10, 14)
		jet.SpreadAngle = Vector2.new(8, 8)
		jet.Acceleration = Vector3.new(0, -25, 0)
		jet.Lifetime = NumberRange.new(0.8, 1)
		jet.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255))
		jet.EmissionDirection = Enum.NormalId.Right -- the cylinder is rotated, so Right points up
		jet.Parent = water
	elseif kind == "Statue" then
		decorPart(model, { Size = Vector3.new(3, 1, 3), CFrame = at(0, 0.5, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Marble })
		decorPart(model, { Size = Vector3.new(2, 2.5, 1.4), CFrame = at(0, 2.3, 0), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal })
		decorPart(model, { Size = Vector3.new(1.5, 1.2, 1.2), CFrame = at(0, 4.2, 0), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal })
		decorPart(model, { Size = Vector3.new(1.1, 0.3, 0.1), CFrame = at(0, 4.3, -0.62), Color = Color3.fromRGB(0, 255, 255), Material = Enum.Material.Neon })
	elseif kind == "Hologram" then
		decorPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3), CFrame = at(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
		local ring = decorPart(model, { Size = Vector3.new(4, 0.3, 0.6), CFrame = at(0, 4, 0), Color = Color3.fromRGB(0, 255, 200), Material = Enum.Material.Neon, CanCollide = false })
		ring:SetAttribute("Spin", 3)
		local ring2 = decorPart(model, { Size = Vector3.new(0.6, 0.3, 4), CFrame = at(0, 4, 0), Color = Color3.fromRGB(0, 255, 200), Material = Enum.Material.Neon, CanCollide = false })
		ring2:SetAttribute("Spin", 3)
		decorPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = at(0, 4, 0), Color = Color3.fromRGB(0, 255, 200), Material = Enum.Material.ForceField, CanCollide = false })
	elseif kind == "GoldGear" then
		decorPart(model, { Size = Vector3.new(3, 1, 3), CFrame = at(0, 0.5, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
		for angle = 0, 2, 1 do
			local tooth = decorPart(model, { Size = Vector3.new(6, 0.8, 1.2), CFrame = at(0, 4, 0) * CFrame.Angles(math.rad(90), angle * math.rad(60), 0), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil, CanCollide = false })
			tooth:SetAttribute("Spin", 1.5)
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 80)
		sparkles.Parent = model:FindFirstChildWhichIsA("BasePart")
	end
	return model
end

local function folderFor(plot)
	local folder = plot.Model:FindFirstChild("Custom")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Custom"
		folder.Parent = plot.Model
	end
	return folder
end

local function buildSign(plot, text)
	local folder = folderFor(plot)
	local old = folder:FindFirstChild("NeonSign")
	if old then
		old:Destroy()
	end
	if text == "" then
		return
	end
	local frontZ = plot.Model.Base.Size.Z / 2 - 3
	local sign = Instance.new("Part")
	sign.Name = "NeonSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Size = Vector3.new(30, 4, 0.4)
	-- Above the gate board, facing out to the aisle like the board does
	sign.CFrame = plot.CFrame * CFrame.new(0, 24.5, frontZ) * CFrame.Angles(0, math.pi, 0)
	sign.Transparency = 1
	sign.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Michroma
	label.TextScaled = true
	label.TextColor3 = CustomConfig.SignColor
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Text = text
	label.Parent = gui
end

local function buildDecorations(player, plot)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local folder = folderFor(plot)
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name ~= "NeonSign" then
			child:Destroy()
		end
	end
	for slot, position in ipairs(CustomConfig.DecorSlots) do
		local id = data.Custom.Decor[tostring(slot)]
		local entry = id and byId[id]
		if entry and entry.Category == "Decor" and owns(player, id) then
			local model = buildDecor(entry.Item.Kind, plot.CFrame * CFrame.new(position))
			model.Name = "DecorSlot" .. slot
			model.Parent = folder
		end
	end
end

-- Filters sign text so everyone may see it. Returns "" if filtering fails.
local function filterSign(player, text)
	if text == "" then
		return ""
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else ""
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for category in pairs(CATEGORIES) do
		player:SetAttribute("Custom_" .. category, data.Custom[category])
	end
	for slot in ipairs(CustomConfig.DecorSlots) do
		player:SetAttribute("Custom_Decor" .. slot, data.Custom.Decor[tostring(slot)] or "")
	end
	player:SetAttribute("Custom_Sign", filteredSigns[player] or "")
	for id in pairs(byId) do
		player:SetAttribute("OwnsCustom_" .. id, owns(player, id))
	end
end

function CustomizationService:ApplyAll(player: Player)
	local plot = PlotService:GetPlot(player)
	if not plot then
		return
	end
	applyPaint(player, plot)
	buildDecorations(player, plot)
	buildSign(plot, filteredSigns[player] or "")
end

-- Floor material/color override for PlotService:Restyle (CosmeticService asks)
function CustomizationService:GetFloorStyle(player: Player)
	local data = DataService:GetData(player)
	local floor = data and byId[data.Custom.Floor]
	if floor and owns(player, data.Custom.Floor) then
		return floor.Item.Color, floor.Item.Material
	end
	return nil, nil
end

-- Remote -----------------------------------------------------------------------------

local function action(player, kind, a, b)
	local data = DataService:GetData(player)
	if not data or type(kind) ~= "string" then
		return
	end
	if kind == "Buy" then
		local entry = type(a) == "string" and byId[a]
		if not entry or entry.Item.VIP or owns(player, a) then
			if entry and entry.Item.VIP and not isVIP(player) then
				Net:Notify(player, "⭐ VIP items need Roblox Premium or the VIP Floor pass.", "error")
			end
			return
		end
		if not EconomyService:TrySpend(player, entry.Item.Price) then
			Net:Notify(player, ("%s costs %s."):format(entry.Item.Name, Format.cash(entry.Item.Price)), "error")
			return
		end
		data.OwnedCustom[a] = true
		Net:Fire(player, "Sfx", "Purchase")
		Net:Notify(player, "Unlocked " .. entry.Item.Name .. "!", "success")
	elseif kind == "Equip" then
		if type(a) ~= "string" or not CATEGORIES[a] or type(b) ~= "string" then
			return
		end
		if b ~= "" and (not byId[b] or byId[b].Category ~= a or not owns(player, b)) then
			return
		end
		data.Custom[a] = b
		local plot = PlotService:GetPlot(player)
		if plot then
			applyPaint(player, plot)
		end
		if a == "Floor" then
			CustomizationService.FloorChanged(player)
		end
	elseif kind == "Decor" then
		local slot = tonumber(a)
		if not slot or slot ~= math.floor(slot) or not CustomConfig.DecorSlots[slot] or type(b) ~= "string" then
			return
		end
		if b ~= "" and (not byId[b] or byId[b].Category ~= "Decor" or not owns(player, b)) then
			return
		end
		data.Custom.Decor[tostring(slot)] = if b == "" then nil else b
		local plot = PlotService:GetPlot(player)
		if plot then
			buildDecorations(player, plot)
		end
	elseif kind == "Sign" then
		if type(a) ~= "string" then
			return
		end
		if os.clock() - (lastSign[player] or 0) < SIGN_COOLDOWN then
			Net:Notify(player, "Wait a few seconds before changing your sign again.", "error")
			return
		end
		lastSign[player] = os.clock()
		local text = string.sub(string.gsub(a, "[%c]", ""), 1, CustomConfig.SignMaxLength)
		data.Custom.Sign = text
		filteredSigns[player] = filterSign(player, text)
		local plot = PlotService:GetPlot(player)
		if plot then
			buildSign(plot, filteredSigns[player])
		end
		if text ~= "" and filteredSigns[player] ~= text then
			Net:Notify(player, "Some words in your sign were filtered.", "info")
		end
	end
	sync(player)
end

CustomizationService.FloorChanged = function(_) end -- set by CosmeticService (re-applies the plot style)

function CustomizationService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	TycoonService = services.TycoonService
	Net = services.Net
end

function CustomizationService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		local data = DataService:GetData(player)
		if not data then
			return
		end
		filteredSigns[player] = filterSign(player, data.Custom.Sign)
		sync(player)
		self:ApplyAll(player)
		-- VIP items appear/disappear with the VIP pass
		player:GetAttributeChangedSignal("Pass_VIPFloor"):Connect(function()
			sync(player)
			self:ApplyAll(player)
		end)
	end)
	-- Newly built items get the paint job too
	TycoonService.ItemUnlocked:Connect(function(player, plot, item)
		if item.Category == "Wall" or item.Category == "Floor" or item.Machine then
			applyPaint(player, plot)
		end
	end)
	PlotService.PlotReleased:Connect(function(player, plot)
		filteredSigns[player] = nil
		local folder = plot.Model:FindFirstChild("Custom")
		if folder then
			folder:ClearAllChildren()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		filteredSigns[player] = nil
		lastSign[player] = nil
	end)
	Net:On("CustomAction", action, 3, 6)
end

return CustomizationService
