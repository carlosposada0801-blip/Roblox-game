--[[
	EconomyService
	The only place cash is changed. Everything goes through the server-side
	save data and is mirrored to leaderstats so the client can display it.
	The client never sends cash amounts; it can only read them.
]]

local DataService

local EconomyService = {}

local function isValidAmount(amount)
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

local function syncLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashValue then
		cashValue.Value = data.Cash
	end
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
	cash.Value = data.Cash
	cash.Parent = leaderstats

	leaderstats.Parent = player
end

function EconomyService:GetCash(player: Player): number
	local data = DataService:GetData(player)
	return data and data.Cash or 0
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
	syncLeaderstats(player, data)
	return true
end

-- Spends cash only if the player can afford it. Returns true on success.
function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = DataService:GetData(player)
	if not data or not isValidAmount(amount) or data.Cash < amount then
		return false
	end

	data.Cash -= amount
	syncLeaderstats(player, data)
	return true
end

-- Re-sends the saved values to leaderstats (e.g. after a data reset).
function EconomyService:Refresh(player: Player)
	local data = DataService:GetData(player)
	if data then
		syncLeaderstats(player, data)
	end
end

return EconomyService
