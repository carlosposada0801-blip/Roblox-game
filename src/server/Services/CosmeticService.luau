--[[
	CosmeticService
	Titles (from achievements and weekly prizes), trails, factory accent
	colors and robot skins (CosmeticConfig). Equipped choices are saved in
	data.Cosmetics; bought/earned ones in data.OwnedCosmetics.
	  Title  -> attribute Title, overhead tag, and a chat tag (client)
	  Trail  -> a glowing Trail behind the character
	  Accent -> recolors your factory's neon (PlotService:Restyle)
	  Skin   -> recolors robots your factory builds (ProductionService asks GetSkin)
	Remote CosmeticAction(action, id): "Buy", "Title", "Trail", "Accent", "Skin"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlotService, PlayerService, AchievementService, AscensionService, CustomizationService, Net

local CosmeticService = {}

local byId = {}
for _, trail in ipairs(CosmeticConfig.Trails) do
	byId[trail.Id] = { Kind = "Trail", Item = trail }
end
for _, accent in ipairs(CosmeticConfig.Accents) do
	byId[accent.Id] = { Kind = "Accent", Item = accent }
end
for _, skin in ipairs(CosmeticConfig.Skins) do
	byId[skin.Id] = { Kind = "Skin", Item = skin }
end
local titleByAchievement = {}
for _, achievement in ipairs(AchievementConfig.Achievements) do
	titleByAchievement[achievement.Id] = achievement.Title
end

local function owns(player, id)
	local data = DataService:GetData(player)
	local entry = byId[id]
	if not (data and entry) then
		return false
	end
	if entry.Item.Achievement then
		return data.Achievements[entry.Item.Achievement] ~= nil
	end
	if entry.Item.Exclusive then
		return data.OwnedCosmetics[id] == true
	end
	return data.OwnedCosmetics[id] == true or (entry.Item.Price or 0) == 0
end

local function ownsTitle(player, title)
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	if data.OwnedTitles[title] then
		return true
	end
	for achievementId in pairs(data.Achievements) do
		if titleByAchievement[achievementId] == title then
			return true
		end
	end
	return false
end

local function applyTrail(player)
	local data = DataService:GetData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (data and root) then
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child.Name == "CosmeticTrail" or child.Name == "TrailTop" or child.Name == "TrailBottom" then
			child:Destroy()
		end
	end
	local entry = byId[data.Cosmetics.Trail]
	if not entry then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.8, 0.4)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(entry.Item.Color)
	trail.LightEmission = 1
	trail.Lifetime = 0.5
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
end

local function applyTitle(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	player:SetAttribute("Title", data.Cosmetics.Title)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("TitleTag")
	if data.Cosmetics.Title == "" then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "TitleTag"
		tag.Size = UDim2.fromOffset(180, 22)
		tag.StudsOffset = Vector3.new(0, 3.6, 0)
		tag.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Sarpanch
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 220, 90)
		label.TextStrokeTransparency = 0.2
		label.Parent = tag
		tag.Parent = head
	end
	tag.Text.Text = data.Cosmetics.Title
end

function CosmeticService:ApplyPlotStyle(player: Player)
	local data = DataService:GetData(player)
	local plot = PlotService:GetPlot(player)
	if not (data and plot) then
		return
	end
	local theme = AscensionService:GetTheme(data.Ascensions)
	local accent = byId[data.Cosmetics.Accent]
	-- A floor picked in Customize wins over the ascension theme's floor
	local floorColor, floorMaterial = CustomizationService:GetFloorStyle(player)
	PlotService:Restyle(plot, {
		Base = floorColor or theme.Base,
		Material = floorMaterial or theme.Material,
		Accent = if accent then accent.Item.Color else theme.Accent,
	})
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for id in pairs(byId) do
		player:SetAttribute("Owns_" .. id, owns(player, id))
	end
	player:SetAttribute("EquippedTrail", data.Cosmetics.Trail)
	player:SetAttribute("EquippedAccent", data.Cosmetics.Accent)
	player:SetAttribute("EquippedSkin", data.Cosmetics.Skin)
	local titles = {}
	for title in pairs(data.OwnedTitles) do
		table.insert(titles, title)
	end
	player:SetAttribute("ExtraTitles", table.concat(titles, "\n"))
	player:SetAttribute("Title", data.Cosmetics.Title)
end

local function action(player, kind, id)
	local data = DataService:GetData(player)
	if not data or type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	if kind == "Buy" then
		local entry = byId[id]
		if not entry or entry.Item.Achievement or entry.Item.Exclusive or owns(player, id) then
			return
		end
		if not EconomyService:TrySpend(player, entry.Item.Price) then
			Net:Notify(player, ("%s costs %s."):format(entry.Item.Name, Format.cash(entry.Item.Price)), "error")
			return
		end
		data.OwnedCosmetics[id] = true
		Net:Fire(player, "Sfx", "Purchase")
		Net:Notify(player, "Unlocked " .. entry.Item.Name .. "!", "success")
	elseif kind == "Title" then
		if id ~= "" and not ownsTitle(player, id) then
			return
		end
		data.Cosmetics.Title = id
		applyTitle(player)
	elseif kind == "Trail" or kind == "Accent" or kind == "Skin" then
		if id ~= "" and (not byId[id] or byId[id].Kind ~= kind or not owns(player, id)) then
			return
		end
		data.Cosmetics[kind] = id
		if kind == "Trail" then
			applyTrail(player)
		elseif kind == "Accent" then
			CosmeticService:ApplyPlotStyle(player)
		end
	end
	sync(player)
end

-- Gives a cosmetic (exclusive skins from the Starter Pack, bosses, weekly prizes, codes, trades).
-- Returns false if the player already owns it.
function CosmeticService:GiveSkin(player: Player, id: string): boolean
	local data = DataService:GetData(player)
	if not (data and byId[id]) or data.OwnedCosmetics[id] then
		return false
	end
	data.OwnedCosmetics[id] = true
	sync(player)
	return true
end

-- Removes an owned cosmetic (trading it away). Unequips it if needed.
function CosmeticService:TakeCosmetic(player: Player, id: string): boolean
	local data = DataService:GetData(player)
	local entry = byId[id]
	if not (data and entry and data.OwnedCosmetics[id]) then
		return false
	end
	data.OwnedCosmetics[id] = nil
	if data.Cosmetics[entry.Kind] == id then
		data.Cosmetics[entry.Kind] = ""
		if entry.Kind == "Trail" then
			applyTrail(player)
		elseif entry.Kind == "Accent" then
			CosmeticService:ApplyPlotStyle(player)
		end
	end
	sync(player)
	return true
end

function CosmeticService:IsTradable(player: Player, id: string): boolean
	local data = DataService:GetData(player)
	local entry = byId[id]
	return data ~= nil and entry ~= nil and entry.Item.Tradable == true and data.OwnedCosmetics[id] == true
end

function CosmeticService:GetName(id: string): string
	local entry = byId[id]
	return if entry then entry.Item.Name else id
end

-- Grants a title that doesn't come from an achievement (weekly leaderboard prizes).
function CosmeticService:GiveTitle(player: Player, title: string)
	local data = DataService:GetData(player)
	if data and not data.OwnedTitles[title] then
		data.OwnedTitles[title] = true
		sync(player)
	end
end

-- The equipped robot skin's config entry, or nil.
function CosmeticService:GetSkin(player: Player)
	local data = DataService:GetData(player)
	local entry = data and byId[data.Cosmetics.Skin]
	if entry and entry.Kind == "Skin" and owns(player, data.Cosmetics.Skin) then
		return entry.Item
	end
	return nil
end

function CosmeticService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	AchievementService = services.AchievementService
	AscensionService = services.AscensionService
	CustomizationService = services.CustomizationService
	Net = services.Net
end

function CosmeticService:Start()
	CustomizationService.FloorChanged = function(player)
		self:ApplyPlotStyle(player)
	end
	PlayerService.PlayerReady:Connect(function(player)
		sync(player)
		self:ApplyPlotStyle(player)
		local function onCharacter(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			applyTrail(player)
			applyTitle(player)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end)
	AchievementService.Unlocked:Connect(function(player)
		sync(player)
	end)
	Net:On("CosmeticAction", action, 3, 6)
end

return CosmeticService
