--[[
	UpgradeService
	Droppers and machines get an "Upgrade" prompt (walk up and press E / tap).
	Levels are saved in data.Levels and reset on rebirth (UpgradeConfig).
	ProductionService asks GetDropperBoosts / GetMachineMultiplier for the effects.
	Prompts are tagged OwnerOnly so the client hides them on other players' plots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, TycoonService, QuestService, Net

local UpgradeService = {}

local function getLevel(player, itemId)
	local data = DataService:GetData(player)
	return data and data.Levels[itemId] or 1
end

function UpgradeService:GetCost(item, level: number): number
	local base = math.max(UpgradeConfig.MinBaseCost, item.Price)
	return math.floor(base * UpgradeConfig.CostScale * UpgradeConfig.CostGrowth ^ (level - 1))
end

-- (value multiplier, speed multiplier)
function UpgradeService:GetDropperBoosts(player: Player, itemId: string)
	local level = getLevel(player, itemId) - 1
	return 1 + level * UpgradeConfig.Dropper.ValuePerLevel, 1 + level * UpgradeConfig.Dropper.SpeedPerLevel
end

-- Scales the machine's own multiplier: x2 at level 3 becomes 2 * (1 + 2 * 0.25)
function UpgradeService:GetMachineMultiplier(player: Player, itemId: string): number
	return 1 + (getLevel(player, itemId) - 1) * UpgradeConfig.Machine.MultiplierPerLevel
end

local function updateVisuals(player, item, model, prompt, label)
	local level = getLevel(player, item.Id)
	label.Text = "Lv " .. level
	if level >= UpgradeConfig.MaxLevel then
		prompt.ActionText = "MAX LEVEL"
		prompt.ObjectText = item.DisplayName .. " Lv " .. level
		prompt.Enabled = false
	else
		prompt.ActionText = ("Upgrade  %s"):format(Format.cash(UpgradeService:GetCost(item, level)))
		prompt.ObjectText = ("%s  Lv %d → %d"):format(item.DisplayName, level, level + 1)
	end
end

local function attach(player, plot, item, model)
	if not (item.Dropper or item.Machine) then
		return
	end
	local anchor = model:FindFirstChild("Body") or model:FindFirstChild("Roof") or model.PrimaryPart
	if not anchor then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt:SetAttribute("OwnerId", player.UserId)
	prompt.Parent = anchor

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelTag"
	billboard.Size = UDim2.fromOffset(60, 22)
	billboard.StudsOffset = Vector3.new(0, anchor.Size.Y / 2 + 1.2, 0)
	billboard.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	billboard.Parent = anchor

	updateVisuals(player, item, model, prompt, label)

	prompt.Triggered:Connect(function(who)
		if who ~= player then
			return
		end
		local data = DataService:GetData(player)
		local level = getLevel(player, item.Id)
		if not data or level >= UpgradeConfig.MaxLevel then
			return
		end
		local cost = UpgradeService:GetCost(item, level)
		if not EconomyService:TrySpend(player, cost) then
			Net:Notify(player, ("Upgrading needs %s."):format(Format.cash(cost)), "error")
			Net:Fire(player, "Sfx", "Denied")
			return
		end
		data.Levels[item.Id] = level + 1
		updateVisuals(player, item, model, prompt, label)
		QuestService:Track(player, "Upgrades", 1)
		Net:Fire(player, "Sfx", "Purchase")
		Net:FireAll("Fx", "Upgrade", anchor.Position)
		Net:Notify(player, ("%s upgraded to Lv %d!"):format(item.DisplayName, level + 1), "success")
	end)
end

function UpgradeService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	QuestService = services.QuestService
	Net = services.Net
end

function UpgradeService:Start()
	TycoonService.ItemUnlocked:Connect(attach)
end

return UpgradeService
