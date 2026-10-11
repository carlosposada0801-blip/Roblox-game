--[[
	DataService
	Loads and saves player data with a session lock, so the same player's data
	can never be edited by two servers at once (no item duplication, no
	rollbacks when hopping servers quickly).

	How the lock works:
	  * Each DataStore entry is { Data = <save file>, Lock = { JobId, Time } }.
	  * Loading claims the lock with UpdateAsync. If another live server holds
	    it, we wait and retry. A lock that hasn't been refreshed for
	    LockExpireSeconds belongs to a dead server and is taken over, and the
	    last load attempt takes it over regardless.
	  * Every save checks that we still own the lock. If another server took
	    it, we stop saving and kick the player instead of overwriting newer data.
	  * Autosave refreshes the lock; leaving or shutting down clears it.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared.Config.DataConfig)
local Signal = require(Shared.Util.Signal)

local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)

local profiles = {} -- [Player] = profile
local pendingReleases = 0
local store

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Fill in any keys the template has that the saved data doesn't (new features).
local function reconcile(data, template)
	for key, default in pairs(template) do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" and next(default) ~= nil then
			reconcile(data[key], default)
		end
	end
	return data
end

-- In-memory stand-in for Studio when API access is off.
local function createMockStore()
	local memory = {}
	return {
		IsMock = true,
		UpdateAsync = function(_, key, transform)
			local result = transform(deepCopy(memory[key]))
			if result ~= nil then
				memory[key] = deepCopy(result)
			end
			return result
		end,
	}
end

local function getStore()
	if RunService:IsStudio() and DataConfig.ForceMockInStudio then
		warn("[DataService] ForceMockInStudio is on: data will NOT persist between play tests.")
		return createMockStore()
	end

	local ok, dataStore = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName)
	end)

	if ok and RunService:IsStudio() then
		ok = pcall(function()
			dataStore:GetAsync("__access_check")
		end)
	end

	if not ok then
		warn(
			"[DataService] DataStores unavailable (in Studio, turn on Game Settings > Security > "
				.. "Enable Studio Access to API Services). Using an in-memory store: data will NOT persist."
		)
		return createMockStore()
	end

	return dataStore
end

local function isLockOurs(lock)
	return lock ~= nil and lock.JobId == JOB_ID
end

local function isLockActive(lock)
	return lock ~= nil and lock.JobId ~= JOB_ID and (os.time() - (lock.Time or 0)) < DataConfig.LockExpireSeconds
end

-- Claims the session lock and returns (true, savedData or nil) or (false).
local function claimAndLoad(key)
	for attempt = 1, DataConfig.LoadAttempts do
		local lockedElsewhere = false
		local loadedData = nil
		local isFinalAttempt = attempt == DataConfig.LoadAttempts

		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored)
				-- UpdateAsync may call this more than once, so reset our outputs each time.
				lockedElsewhere = false
				stored = stored or {}

				if isLockActive(stored.Lock) and not isFinalAttempt then
					lockedElsewhere = true
					return nil -- cancel the write and try again later
				end

				if isLockActive(stored.Lock) then
					warn(("[DataService] Taking over session lock for %s from %s"):format(key, stored.Lock.JobId))
				end

				stored.Lock = { JobId = JOB_ID, Time = os.time() }
				loadedData = stored.Data
				return stored
			end)
		end)

		if ok and not lockedElsewhere then
			return true, loadedData
		end

		if not ok then
			warn(("[DataService] Load attempt %d for %s failed: %s"):format(attempt, key, tostring(err)))
		end

		if not isFinalAttempt then
			task.wait(DataConfig.LoadRetryDelay)
		end
	end

	return false
end

-- Writes profile.Data. If release is true the lock is cleared afterwards.
local function writeProfile(profile, release)
	if profile.LockLost then
		return false
	end

	-- Never run two writes for the same profile at once.
	while profile.Saving do
		task.wait()
	end
	profile.Saving = true

	local saved = false
	for attempt = 1, DataConfig.SaveAttempts do
		local lockLost = false
		local snapshot = deepCopy(profile.Data)

		local ok, err = pcall(function()
			store:UpdateAsync(profile.Key, function(stored)
				lockLost = false
				stored = stored or {}

				if not isLockOurs(stored.Lock) then
					lockLost = true
					return nil
				end

				stored.Data = snapshot
				stored.Lock = if release then nil else { JobId = JOB_ID, Time = os.time() }
				return stored
			end)
		end)

		if ok and lockLost then
			profile.LockLost = true
			warn(("[DataService] Lost session lock for %s; another server owns this data now."):format(profile.Key))
			local player = profile.Player
			if player.Parent then
				player:Kick("Your data was loaded on another server. Please rejoin.")
			end
			break
		elseif ok then
			saved = true
			break
		else
			warn(("[DataService] Save attempt %d for %s failed: %s"):format(attempt, profile.Key, tostring(err)))
			if attempt < DataConfig.SaveAttempts then
				task.wait(2 ^ attempt)
			end
		end
	end

	profile.Saving = false
	return saved
end

function DataService:Init()
	store = getStore()
	self.IsMock = store.IsMock == true
end

function DataService:Start()
	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveInterval)
			for _, profile in pairs(profiles) do
				task.spawn(writeProfile, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(function()
				self:Release(player)
			end)
		end

		-- Wait (up to the ~30s Roblox gives us) for every release to finish.
		local deadline = os.clock() + 25
		while pendingReleases > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

-- Yields. Returns the profile, or nil if loading failed (the player is kicked).
function DataService:LoadAsync(player: Player)
	if profiles[player] then
		return profiles[player]
	end

	local key = DataConfig.KeyPrefix .. player.UserId
	local ok, savedData = claimAndLoad(key)

	if not ok then
		if player.Parent then
			player:Kick("Couldn't load your data. Please rejoin in a minute.")
		end
		return nil
	end

	local profile = {
		Player = player,
		Key = key,
		Data = reconcile(savedData or deepCopy(DataConfig.Template), DataConfig.Template),
		Saving = false,
		LockLost = false,
	}

	-- The player left while we were loading: hand the lock straight back.
	if player.Parent == nil then
		writeProfile(profile, true)
		return nil
	end

	profiles[player] = profile
	self.ProfileLoaded:Fire(player, profile)
	return profile
end

function DataService:GetProfile(player: Player)
	return profiles[player]
end

-- Returns the live data table. Mutate it only on the server.
function DataService:GetData(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:SaveAsync(player: Player)
	local profile = profiles[player]
	if profile then
		return writeProfile(profile, false)
	end
	return false
end

-- Saves one last time and clears the lock. Safe to call more than once.
function DataService:Release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil

	pendingReleases += 1
	writeProfile(profile, true)
	pendingReleases -= 1
end

-- Replaces the player's data with a fresh template (used by Studio dev commands).
function DataService:ResetData(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data = deepCopy(DataConfig.Template)
	end
end

return DataService
