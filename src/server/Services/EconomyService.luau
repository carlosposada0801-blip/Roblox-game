--[[
	EconomyService
	The only place cash and player stats change. Everything is stored in the
	server-side save data and mirrored to the client read-only:
	  leaderstats: Cash, Rebirths  (player list)
	  attributes:  PendingCash, Robots, RobotsBuilt, Prototypes, CashMultiplier
	The client never sends amounts; it can only read them.

	Earning flow: collector -> Earn(value) -> x multipliers -> PendingCash
	              cash pad (or Auto-Collect pass) -> CollectPending -> Cash
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local DataService

local EconomyService = {}

local MIRRORED_STATS = { "PendingCash", "Robots", "RobotsBuilt", "Prototypes" }

local function isValidAmount(amount)
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

local function getStat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

local function sync(player, data)
	local cash = getStat(player, "Cash")
	if cash then
		cash.Value = data.Cash
	end
	local rebirths = getStat(player, "Rebirths")
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	for _, key in ipairs(MIRRORED_STATS) do
		player:SetAttribute(key, math.floor(data[key]))
	end
	player:SetAttribute("CashMultiplier", EconomyService:GetEarnMultiplier(player))
end

function EconomyService:Init(services)
	DataService = services.DataService
end

-- Called once per player after their data loads.
function EconomyService:SetupPlayer(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = leaderstats:FindFirstChild("Cash") or Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats

	local rebirths = leaderstats:FindFirstChild("Rebirths") or Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	sync(player, data)

	-- Pass attributes change the multiplier shown in the UI
	player:GetAttributeChangedSignal("Pass_DoubleCash"):Connect(function()
		self:Refresh(player)
	end)
	player:GetAttributeChangedSignal("Pass_AutoCollect"):Connect(function()
		if player:GetAttribute("Pass_AutoCollect") then
			self:CollectPending(player)
		end
	end)
end

function EconomyService:Refresh(player: Player)
	local data = DataService:GetData(player)
	if data then
		sync(player, data)
	end
end

function EconomyService:GetCash(player: Player): number
	local data = DataService:GetData(player)
	return data and data.Cash or 0
end

-- Rebirths x 2x Cash pass
function EconomyService:GetEarnMultiplier(player: Player): number
	local data = DataService:GetData(player)
	local multiplier = RebirthConfig.GetMultiplier(data and data.Rebirths or 0)
	if player:GetAttribute("Pass_DoubleCash") then
		multiplier *= MonetizationConfig.DoubleCashMultiplier
	end
	return multiplier
end

-- Adds cash exactly as given (no multipliers). Returns true on success.
function EconomyService:AddCash(player: Player, amount: number): boolean
	local data = DataService:GetData(player)
	if not data or not isValidAmount(amount) then
		return false
	end

	amount = math.floor(amount)
	data.Cash += amount
	data.TotalEarned += amount
	sync(player, data)
	return true
end

-- Spends cash only if the player can afford it. Returns true on success.
function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = DataService:GetData(player)
	if not data or not isValidAmount(amount) or data.Cash < amount then
		return false
	end

	data.Cash -= amount
	sync(player, data)
	return true
end

-- Collector income: applies multipliers, then waits on the cash pad
-- (or goes straight to cash with Auto-Collect). Returns the amount earned.
function EconomyService:Earn(player: Player, baseValue: number): number
	local data = DataService:GetData(player)
	if not data or not isValidAmount(baseValue) then
		return 0
	end

	local amount = baseValue * self:GetEarnMultiplier(player)
	data.PendingCash += amount

	if player:GetAttribute("Pass_AutoCollect") then
		self:CollectPending(player)
	else
		player:SetAttribute("PendingCash", math.floor(data.PendingCash))
	end
	return amount
end

-- Moves whole dollars from the pad into cash. Returns the amount moved.
function EconomyService:CollectPending(player: Player): number
	local data = DataService:GetData(player)
	if not data then
		return 0
	end

	local whole = math.floor(data.PendingCash)
	if whole <= 0 then
		return 0
	end

	data.PendingCash -= whole
	data.Cash += whole
	data.TotalEarned += whole
	sync(player, data)
	return whole
end

-- Changes a numeric stat (Robots, Prototypes, ...) and mirrors it.
function EconomyService:AddStat(player: Player, key: string, amount: number)
	local data = DataService:GetData(player)
	if not data or type(data[key]) ~= "number" then
		return
	end
	data[key] = math.max(0, data[key] + amount)
	sync(player, data)
end

return EconomyService
