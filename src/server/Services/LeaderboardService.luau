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
local Time = require(Shared.Util.Time)

local DataService, PlayerService, CosmeticService, Net

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

	local store, week
	if not DataService.IsMock then
		week = if config.Weekly then Time.week() else nil
		local name = if week then config.Store .. "_W" .. week else config.Store
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		store = ok and result or nil
	end

	table.insert(boards, { Config = config, Store = store, Week = week, Rows = rows, Status = status })
end

local function weeklyStore(config, week)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, config.Store .. "_W" .. week)
	return if ok then store else nil
end

-- A player's score for a board right now
local function scoreFor(board, data)
	if board.Config.Custom then
		return 0
	elseif board.Config.Weekly then
		return if data.Weekly.Week == Time.week() then math.floor(data.Weekly.Earned) else 0
	end
	return math.floor(tonumber(data[board.Config.Stat]) or 0)
end

local function refresh(board)
	-- New week: switch the weekly board to a fresh store
	if board.Config.Weekly and board.Store and board.Week ~= Time.week() then
		board.Week = Time.week()
		board.Store = weeklyStore(board.Config, board.Week) or board.Store
	end
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
	board.Status.Text = if board.Config.Weekly
		then ("Resets in %s  •  Top 3 win a title + skin!"):format(Time.format(Time.weekEnds(board.Week) - os.time()))
		else "Updates every minute"
	for rank, row in ipairs(board.Rows) do
		local entry = entries[rank]
		if entry then
			local medal = ({ "🥇", "🥈", "🥉" })[rank] or ("  " .. rank .. ".")
			local name = if board.Config.Custom then entry.key else getName(tonumber(entry.key))
			row.Text = ("  %s %s — %s%s"):format(medal, name, board.Config.Prefix or "", Format.abbreviate(entry.value))
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
		local value = scoreFor(board, data)
		if board.Store and value > 0 then
			task.spawn(pcall, function()
				board.Store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

-- For boards whose rows aren't players (crews)
function LeaderboardService:SetCustomScore(boardId: string, key: string, value: number)
	for _, board in ipairs(boards) do
		if board.Config.Id == boardId and board.Store then
			task.spawn(pcall, function()
				board.Store:SetAsync(key, math.floor(value))
			end)
		end
	end
end

-- Cash earned counts toward this week's board (EconomyService calls this)
function LeaderboardService:AddWeeklyEarnings(player: Player, amount: number)
	local data = DataService:GetData(player)
	if not data or amount <= 0 then
		return
	end
	local week = Time.week()
	if data.Weekly.Week ~= week then
		data.Weekly = { Week = week, Earned = 0 }
	end
	data.Weekly.Earned += amount
end

-- Top 3 of a finished week get their prize on their next join
local function checkWeeklyPrizes(player)
	local data = DataService:GetData(player)
	local board
	for _, candidate in ipairs(boards) do
		if candidate.Config.Weekly then
			board = candidate
		end
	end
	if not (data and board and board.Store) then
		return
	end
	local current = Time.week()
	for week = current - 1, current - LeaderboardConfig.WeeklyLookback, -1 do
		if not data.WeeklyClaimed[tostring(week)] then
			local store = weeklyStore(board.Config, week)
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, #LeaderboardConfig.WeeklyPrizes, 1)
			end)
			if ok and player.Parent then
				for rank, entry in ipairs(pages:GetCurrentPage()) do
					local prize = LeaderboardConfig.WeeklyPrizes[rank]
					if prize and tonumber(entry.key) == player.UserId then
						data.WeeklyClaimed[tostring(week)] = true
						CosmeticService:GiveTitle(player, prize.Title)
						CosmeticService:GiveSkin(player, prize.Skin)
						Net:Notify(player, ("🏆 You finished #%d on last week's board! You won the title %s and the Weekly Champion robot skin!"):format(rank, prize.Title), "special")
						Net:Fire(player, "Fx", "Confetti")
						Net:Fire(player, "Sfx", "Rebirth")
					end
				end
			end
		end
	end
end

function LeaderboardService:Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService
	CosmeticService = services.CosmeticService
	Net = services.Net
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
		task.spawn(checkWeeklyPrizes, player)
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
