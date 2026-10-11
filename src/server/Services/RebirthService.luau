--[[
	RebirthService
	  * RequestRebirth (client asks, server decides): needs cash >= the rebirth
	    cost. Resets cash, pending cash and every bought item; adds 1 rebirth,
	    which raises the permanent cash multiplier (RebirthConfig).
	    Workers, robots, Prototypes and game passes are kept.
	  * Rebirths show in the player list (leaderstats) and on a global
	    "Top Rebirths" board in the lobby, backed by an OrderedDataStore.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, TycoonService, PlayerService, Net

local RebirthService = {}

local orderedStore
local boardRows = {}
local boardStatus
local nameCache = {}

-- Leaderboard ----------------------------------------------------------------

local function buildBoard()
	local position = Vector3.new(0, 9, 24)
	-- Beside the walkway; lookAt points the Front face toward the walkway (-Z)
	local boardCFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))

	local board = Instance.new("Part")
	board.Name = "RebirthLeaderboard"
	board.Anchored = true
	board.Size = Vector3.new(16, 16, 1)
	board.CFrame = boardCFrame
	board.Color = Color3.fromRGB(25, 27, 34)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = workspace

	for _, x in ipairs({ -7, 7 }) do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(1, 17, 1)
		post.CFrame = boardCFrame * CFrame.new(x, -0.5, 0.8)
		post.Color = Color3.fromRGB(255, 170, 0)
		post.Material = Enum.Material.Neon
		post.Parent = board
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.14)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.Text = "🏆 Top Rebirths"
	title.Parent = gui

	boardStatus = Instance.new("TextLabel")
	boardStatus.BackgroundTransparency = 1
	boardStatus.Position = UDim2.fromScale(0, 0.14)
	boardStatus.Size = UDim2.fromScale(1, 0.06)
	boardStatus.Font = Enum.Font.GothamMedium
	boardStatus.TextScaled = true
	boardStatus.TextColor3 = Color3.fromRGB(170, 175, 185)
	boardStatus.Text = "Loading..."
	boardStatus.Parent = gui

	for rank = 1, RebirthConfig.LeaderboardSize do
		local row = Instance.new("TextLabel")
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(35, 38, 47) else Color3.fromRGB(30, 32, 40)
		row.BorderSizePixel = 0
		row.Position = UDim2.fromScale(0.04, 0.21 + (rank - 1) * 0.077)
		row.Size = UDim2.fromScale(0.92, 0.072)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		boardRows[rank] = row
	end
end

local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else ("User " .. userId)
	return nameCache[userId]
end

local function refreshBoard()
	if not orderedStore then
		boardStatus.Text = "Needs Studio API access / a live server"
		return
	end

	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, RebirthConfig.LeaderboardSize, 1)
	end)
	if not ok then
		boardStatus.Text = "Couldn't load right now"
		return
	end

	local entries = pages:GetCurrentPage()
	boardStatus.Text = "Updates every minute"
	for rank, row in ipairs(boardRows) do
		local entry = entries[rank]
		if entry then
			local medal = ({ "🥇", "🥈", "🥉" })[rank] or ("  " .. rank .. ".")
			row.Text = ("  %s %s — %s"):format(medal, getName(tonumber(entry.key)), Format.abbreviate(entry.value))
		else
			row.Text = ""
		end
	end
end

local function saveToBoard(player, rebirths)
	if orderedStore and rebirths > 0 then
		task.spawn(function()
			pcall(function()
				orderedStore:SetAsync(tostring(player.UserId), rebirths)
			end)
		end)
	end
end

-- Rebirth --------------------------------------------------------------------

local function requestRebirth(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end

	local cost = RebirthConfig.GetCost(data.Rebirths)
	if data.Cash < cost then
		Net:Notify(player, ("You need %s to rebirth."):format(Format.cash(cost)), "error")
		return
	end

	data.Cash = 0
	data.PendingCash = 0
	data.Rebirths += 1

	TycoonService:ResetTycoon(player)
	EconomyService:Refresh(player)
	saveToBoard(player, data.Rebirths)
	task.spawn(DataService.SaveAsync, DataService, player)

	local multiplier = RebirthConfig.GetMultiplier(data.Rebirths)
	Net:Notify(player, ("Rebirth %d! Cash is now x%s forever."):format(data.Rebirths, tostring(multiplier)), "special")
	Net:NotifyAll(("%s rebirthed! (Rebirth %d)"):format(player.DisplayName, data.Rebirths), "info")
end

function RebirthService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	PlayerService = services.PlayerService
	Net = services.Net

	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, RebirthConfig.LeaderboardStore)
	if ok and not DataService.IsMock then
		orderedStore = store
	end
end

function RebirthService:Start()
	buildBoard()

	Net:On("RequestRebirth", requestRebirth, 0.5, 1)

	PlayerService.PlayerReady:Connect(function(player)
		local data = DataService:GetData(player)
		if data then
			saveToBoard(player, data.Rebirths)
		end
	end)

	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(RebirthConfig.LeaderboardRefresh)
		end
	end)
end

return RebirthService
