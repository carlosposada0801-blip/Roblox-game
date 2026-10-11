--[[
	CrewService
	Crews (clans) that work across servers (CrewConfig). Crew records live
	in a DataStore and are always changed with UpdateAsync, so two servers
	can't overwrite each other.
	  Create(name) costs cash; anyone can Join(name) until it's full.
	  Members Donate cash to the crew bank; the owner Upgrades the crew level,
	  which gives every member +BonusPerLevel cash.
	Attributes: CrewName, CrewLevel, CrewBank, CrewOwner (bool), CrewMembers
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrewConfig = require(Shared.Config.CrewConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlayerService, LeaderboardService, Net

local CrewService = {}

local store
local cache = {} -- [crewKey] = record (refreshed periodically)

local function keyFor(name)
	return string.lower(name)
end

local function memoryStore()
	local memory = {}
	return {
		UpdateAsync = function(_, key, transform)
			local result = transform(memory[key])
			if result ~= nil then
				memory[key] = result
			end
			return memory[key]
		end,
		GetAsync = function(_, key)
			return memory[key]
		end,
	}
end

local function update(name, transform)
	local ok, result = pcall(function()
		return store:UpdateAsync(keyFor(name), transform)
	end)
	if ok and result then
		cache[keyFor(name)] = result
	end
	return ok, result
end

local function fetch(name)
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(name))
	end)
	if ok then
		cache[keyFor(name)] = result
		return result
	end
	return cache[keyFor(name)]
end

function CrewService:GetMultiplier(player: Player): number
	local level = player:GetAttribute("CrewLevel") or 0
	if level <= 1 then
		return 1
	end
	return 1 + (level - 1) * CrewConfig.BonusPerLevel
end

local function applyRecord(player, record)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if not record or not record.Members[tostring(player.UserId)] then
		data.Crew = ""
		record = nil
	end
	player:SetAttribute("CrewName", if record then record.Name else "")
	player:SetAttribute("CrewLevel", if record then record.Level else 0)
	player:SetAttribute("CrewBank", if record then record.Bank else 0)
	player:SetAttribute("CrewOwner", record ~= nil and record.Owner == player.UserId)
	local count = 0
	for _ in pairs(record and record.Members or {}) do
		count += 1
	end
	player:SetAttribute("CrewMembers", count)
	EconomyService:Refresh(player)
end

local function refresh(player)
	local data = DataService:GetData(player)
	if data and data.Crew ~= "" then
		applyRecord(player, fetch(data.Crew))
	else
		applyRecord(player, nil)
	end
end

local function refreshCrewMembersHere(name)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("CrewName") == name then
			applyRecord(player, cache[keyFor(name)])
		end
	end
end

local function validName(name)
	if type(name) ~= "string" then
		return false
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	local length = #name
	return length >= CrewConfig.NameLength[1] and length <= CrewConfig.NameLength[2] and string.match(name, CrewConfig.NamePattern) ~= nil, name
end

local function crewAction(player, action, arg)
	local data = DataService:GetData(player)
	if not data or type(action) ~= "string" then
		return
	end
	local userKey = tostring(player.UserId)

	if action == "Create" or action == "Join" then
		if data.Crew ~= "" then
			Net:Notify(player, "Leave your current crew first.", "error")
			return
		end
		local ok, name = validName(arg)
		if not ok then
			Net:Notify(player, ("Crew names are %d-%d letters/numbers."):format(CrewConfig.NameLength[1], CrewConfig.NameLength[2]), "error")
			return
		end
		if action == "Create" then
			if data.Cash < CrewConfig.CreateCost then
				Net:Notify(player, ("Creating a crew costs %s."):format(Format.cash(CrewConfig.CreateCost)), "error")
				return
			end
			local taken = false
			local success = update(name, function(record)
				if record then
					taken = true
					return nil
				end
				return { Name = name, Owner = player.UserId, Members = { [userKey] = player.DisplayName }, Bank = 0, Level = 1, Donated = 0 }
			end)
			if not success or taken then
				Net:Notify(player, if taken then "That crew name is taken." else "Couldn't create the crew right now.", "error")
				return
			end
			EconomyService:TrySpend(player, CrewConfig.CreateCost)
			data.Crew = name
			Net:Notify(player, "🛡️ Created crew " .. name .. "!", "success")
		else
			local status = "missing"
			update(name, function(record)
				if not record then
					status = "missing"
					return nil
				end
				local count = 0
				for _ in pairs(record.Members) do
					count += 1
				end
				if count >= CrewConfig.MaxMembers then
					status = "full"
					return nil
				end
				status = "ok"
				record.Members[userKey] = player.DisplayName
				return record
			end)
			if status ~= "ok" then
				Net:Notify(player, if status == "full" then "That crew is full." else "No crew with that name.", "error")
				return
			end
			data.Crew = cache[keyFor(name)].Name
			Net:Notify(player, "🛡️ Joined crew " .. data.Crew .. "!", "success")
		end
		refresh(player)
		refreshCrewMembersHere(data.Crew)
	elseif action == "Leave" then
		if data.Crew == "" then
			return
		end
		local name = data.Crew
		update(name, function(record)
			if not record then
				return nil
			end
			record.Members[userKey] = nil
			if record.Owner == player.UserId then
				-- Hand ownership to another member (or leave it ownerless if empty)
				record.Owner = 0
				for id in pairs(record.Members) do
					record.Owner = tonumber(id)
					break
				end
			end
			return record
		end)
		data.Crew = ""
		refresh(player)
		refreshCrewMembersHere(name)
		Net:Notify(player, "You left " .. name .. ".", "info")
	elseif action == "Donate" then
		local amount = tonumber(arg)
		if data.Crew == "" or not amount then
			return
		end
		amount = math.floor(math.clamp(amount, 0, data.Cash))
		if amount <= 0 or not EconomyService:TrySpend(player, amount) then
			return
		end
		local ok = update(data.Crew, function(record)
			if not record or not record.Members[userKey] then
				return nil
			end
			record.Bank += amount
			record.Donated = (record.Donated or 0) + amount
			return record
		end)
		if not ok then
			EconomyService:AddCash(player, amount) -- refund
			return
		end
		Net:Notify(player, ("Donated %s to %s."):format(Format.cash(amount), data.Crew), "success")
		refreshCrewMembersHere(data.Crew)
	elseif action == "Upgrade" then
		if data.Crew == "" then
			return
		end
		local result = "fail"
		update(data.Crew, function(record)
			if not record or record.Owner ~= player.UserId then
				result = "owner"
				return nil
			end
			if record.Level >= CrewConfig.MaxLevel then
				result = "max"
				return nil
			end
			local cost = CrewConfig.LevelCost(record.Level)
			if record.Bank < cost then
				result = "bank"
				return nil
			end
			record.Bank -= cost
			record.Level += 1
			result = "ok"
			return record
		end)
		if result == "ok" then
			local record = cache[keyFor(data.Crew)]
			Net:Notify(player, ("🛡️ %s is now level %d! Members get +%d%% cash."):format(data.Crew, record.Level, (record.Level - 1) * CrewConfig.BonusPerLevel * 100), "special")
			LeaderboardService:SetCustomScore("Crews", record.Name, record.Level)
			refreshCrewMembersHere(data.Crew)
		else
			local messages = { owner = "Only the crew owner can upgrade.", max = "Your crew is max level!", bank = "Not enough cash in the crew bank.", fail = "Couldn't upgrade right now." }
			Net:Notify(player, messages[result], "error")
		end
	end
end

function CrewService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	LeaderboardService = services.LeaderboardService
	Net = services.Net
	if DataService.IsMock then
		store = memoryStore()
	else
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, CrewConfig.StoreName)
		store = if ok then result else memoryStore()
	end
end

function CrewService:Start()
	PlayerService.PlayerReady:Connect(refresh)
	Net:On("CrewAction", crewAction, 1, 3)
	-- Pick up changes made by crew mates on other servers
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("DataLoaded") then
					refresh(player)
				end
			end
		end
	end)
end

return CrewService
