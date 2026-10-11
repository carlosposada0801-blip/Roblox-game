--[[
	LeaderboardService
	Global leaderboards (LeaderboardConfig) backed by OrderedDataStores,
	shown on boards in the lobby. Scores are written when a player joins,
	every few minutes, and when they leave.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LeaderboardConfig = require(Shared.Config.LeaderboardConfig)
local Format = require(Shared.Util.Format)

local DataService, PlayerService

local LeaderboardService = {}

local boards = {} -- { Config, Store, Rows, Status }
local nameCache = {}

local function getName(userId)
	if not nameCache[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		nameCache[userId] = if ok then name else ("User " .. userId)
	end
	return nameCache[userId]
end

local function buildBoard(config, parent)
	local position = config.Position
	local boardCFrame = CFrame.lookAt(position, position + config.Facing)

	local board = Instance.new("Part")
	board.Name = config.Id .. "Board"
	board.Anchored = true
	board.Size = Vector3.new(16, 16, 1)
	board.CFrame = boardCFrame
	board.Color = Color3.fromRGB(18, 20, 28)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = parent

	-- Frame and hazard-striped legs
	for _, x in ipairs({ -7.6, 7.6 }) do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, 17, 0.8)
		post.CFrame = boardCFrame * CFrame.new(x, -0.5, 0.2)
		post.Color = Color3.fromRGB(0, 220, 255)
		post.Material = Enum.Material.Neon
		post.Parent = board
	end
	local top = Instance.new("Part")
	top.Anchored = true
	top.Size = Vector3.new(16.8, 0.8, 0.8)
	top.CFrame = boardCFrame * CFrame.new(0, 8.2, 0.2)
	top.Color = Color3.fromRGB(0, 220, 255)
	top.Material = Enum.Material.Neon
	top.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local gradient = Instance.new("Frame")
	gradient.Size = UDim2.fromScale(1, 1)
	gradient.BackgroundColor3 = Color3.new(1, 1, 1)
	gradient.BorderSizePixel = 0
	local uiGradient = Instance.new("UIGradient")
	uiGradient.Color = ColorSequence.new(Color3.fromRGB(20, 30, 60), Color3.fromRGB(40, 10, 60))
	uiGradient.Rotation = 90
	uiGradient.Parent = gradient
	gradient.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.14)
	title.Font = Enum.Font.Sarpanch
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	title.Text = config.Title
	title.Parent = gui

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.14)
	status.Size = UDim2.fromScale(1, 0.06)
	status.Font = Enum.Font.GothamMedium
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(150, 190, 230)
	status.Text = "Loading..."
	status.Parent = gui

	local rows = {}
	for rank = 1, LeaderboardConfig.Size do
		local row = Instance.new("TextLabel")
		row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		row.BackgroundTransparency = if rank % 2 == 0 then 0.6 else 0.75
		row.BorderSizePixel = 0
		row.Position = UDim2.fromScale(0.04, 0.21 + (rank - 1) * 0.077)
		row.Size = UDim2.fromScale(0.92, 0.072)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		rows[rank] = row
	end

	local store
	if not DataService.IsMock then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, config.Store)
		store = ok and result or nil
	end

	table.insert(boards, { Config = config, Store = store, Rows = rows, Status = status })
end

local function refresh(board)
	if not board.Store then
		board.Status.Text = "Needs Studio API access / a live server"
		return
	end
	local ok, pages = pcall(function()
		return board.Store:GetSortedAsync(false, LeaderboardConfig.Size, 1)
	end)
	if not ok then
		board.Status.Text = "Couldn't load right now"
		return
	end
	local entries = pages:GetCurrentPage()
	board.Status.Text = "Updates every minute"
	for rank, row in ipairs(board.Rows) do
		local entry = entries[rank]
		if entry then
			local medal = ({ "🥇", "🥈", "🥉" })[rank] or ("  " .. rank .. ".")
			row.Text = ("  %s %s — %s"):format(medal, getName(tonumber(entry.key)), Format.abbreviate(entry.value))
		else
			row.Text = ""
		end
	end
end

function LeaderboardService:SaveScores(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for _, board in ipairs(boards) do
		local value = math.floor(tonumber(data[board.Config.Stat]) or 0)
		if board.Store and value > 0 then
			task.spawn(pcall, function()
				board.Store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

function LeaderboardService:Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService
end

function LeaderboardService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	for _, config in ipairs(LeaderboardConfig.Boards) do
		buildBoard(config, folder)
	end

	PlayerService.PlayerReady:Connect(function(player)
		self:SaveScores(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:SaveScores(player)
	end)

	task.spawn(function()
		while true do
			for _, board in ipairs(boards) do
				refresh(board)
			end
			task.wait(LeaderboardConfig.Refresh)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in ipairs(Players:GetPlayers()) do
				self:SaveScores(player)
			end
		end
	end)
end

return LeaderboardService
