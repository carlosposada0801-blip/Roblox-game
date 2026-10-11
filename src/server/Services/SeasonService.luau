--[[
	SeasonService
	Turns on seasonal events by month (SeasonConfig): lobby decorations and
	a limited egg in the Pets menu. workspace attribute "Season" = id or "".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeasonConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.SeasonConfig)

local SeasonService = {}

local active = ""

function SeasonService:GetActive(): string
	return active
end

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

-- Lobby spots already used by portals, boards, lamps and the spawn
local BUSY = {
	Vector3.new(0, 0, 24), Vector3.new(-40, 0, 24), Vector3.new(40, 0, 24), Vector3.new(-40, 0, -24),
	Vector3.new(0, 0, -20), Vector3.new(-120, 0, -20), Vector3.new(120, 0, -20), Vector3.new(-80, 0, 15),
}
local function isFree(position)
	for _, busy in ipairs(BUSY) do
		if math.abs(position.X - busy.X) < 12 and math.abs(position.Z - busy.Z) < 12 then
			return false
		end
	end
	return true
end

local function decorate(id, folder)
	local season = SeasonConfig.Seasons[id]
	for x = -190, 190, 38 do
		for _, z in ipairs({ -24, 24 }) do
			local position = Vector3.new(x + 12, 0, z)
			if not isFree(position) then
				continue
			end
			if id == "Halloween" then
				local pumpkin = part({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3.4, 4), CFrame = CFrame.new(position + Vector3.new(0, 1.7, 0)), Color = Color3.fromRGB(255, 120, 20), Material = Enum.Material.SmoothPlastic }, folder)
				part({ Name = "Face", Size = Vector3.new(2, 0.8, 0.2), CFrame = pumpkin.CFrame * CFrame.new(0, 0.2, if z > 0 then -2 else 2), Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Neon }, folder)
				part({ Name = "Stem", Size = Vector3.new(0.5, 0.8, 0.5), CFrame = pumpkin.CFrame * CFrame.new(0, 2, 0), Color = Color3.fromRGB(70, 110, 40) }, folder)
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 140, 30)
				light.Range = 12
				light.Parent = pumpkin
			else
				local tree = part({ Name = "SnowTree", Size = Vector3.new(4, 6, 4), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(40, 110, 60), Material = Enum.Material.Grass }, folder)
				part({ Name = "Snow", Size = Vector3.new(4.2, 0.6, 4.2), CFrame = tree.CFrame * CFrame.new(0, 3, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow }, folder)
				local star = part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = tree.CFrame * CFrame.new(0, 3.8, 0), Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Neon }, folder)
				star:SetAttribute("Blink", true)
			end
		end
	end
	-- Floating banner over the walkway
	local anchor = part({ Name = "SeasonBanner", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 26, 0), Transparency = 1, CanCollide = false, CanQuery = false }, folder)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(60, 6)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = season.Color
	label.TextStrokeTransparency = 0
	label.Text = season.Name .. " EVENT"
	label.Parent = billboard
	billboard.Parent = anchor
end

function SeasonService:Init()
	if SeasonConfig.Override and SeasonConfig.Seasons[SeasonConfig.Override] then
		active = SeasonConfig.Override
	else
		local month = tonumber(os.date("!%m")) or 0
		for id, season in pairs(SeasonConfig.Seasons) do
			if table.find(season.Months, month) then
				active = id
			end
		end
	end
	workspace:SetAttribute("Season", active)
end

function SeasonService:Start()
	if active ~= "" then
		local folder = Instance.new("Folder")
		folder.Name = "SeasonDecor"
		folder.Parent = workspace
		decorate(active, folder)
	end
end

return SeasonService
