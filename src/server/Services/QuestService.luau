--[[
	QuestService
	Three daily quests per player (QuestConfig). Other services report
	progress with QuestService:Track(player, stat, amount). Finished quests
	are claimed from the Quests menu (ClaimQuest remote).
	Mirrored to the client as the attribute QuestsJson.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)

local DataService, EconomyService, PlayerService, Net

local QuestService = {}

local questsById = {}
for _, quest in ipairs(QuestConfig.Pool) do
	questsById[quest.Id] = quest
end

local function today()
	return os.time() // 86400
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local view = {}
	for index, entry in ipairs(data.Quests.List) do
		local quest = questsById[entry.Id]
		if quest then
			view[index] = {
				Text = quest.Text:format(entry.Goal),
				Progress = math.floor(entry.Progress),
				Goal = entry.Goal,
				Claimed = entry.Claimed,
				Reward = quest.Reward,
			}
		end
	end
	player:SetAttribute("QuestsJson", HttpService:JSONEncode(view))
end

-- Gives the player a fresh set of quests if theirs are from a previous day.
local function refresh(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if data.Quests.Day == today() and #data.Quests.List > 0 then
		return
	end

	local pool = table.clone(QuestConfig.Pool)
	local list = {}
	for _ = 1, math.min(QuestConfig.QuestsPerDay, #pool) do
		local quest = table.remove(pool, math.random(#pool))
		table.insert(list, {
			Id = quest.Id,
			Goal = quest.Goals[math.random(#quest.Goals)],
			Progress = 0,
			Claimed = false,
		})
	end
	data.Quests = { Day = today(), List = list }
end

function QuestService:Track(player: Player, stat: string, amount: number?)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	refresh(player)
	local changed = false
	for _, entry in ipairs(data.Quests.List) do
		local quest = questsById[entry.Id]
		if quest and quest.Stat == stat and not entry.Claimed and entry.Progress < entry.Goal then
			entry.Progress = math.min(entry.Goal, entry.Progress + (amount or 1))
			changed = true
			if entry.Progress >= entry.Goal then
				Net:Notify(player, "✅ Quest complete: " .. quest.Text:format(entry.Goal) .. ". Claim it in Quests!", "success")
				Net:Fire(player, "Sfx", "Purchase")
			end
		end
	end
	if changed then
		sync(player)
	end
end

local function claim(player, index)
	local data = DataService:GetData(player)
	if not data or type(index) ~= "number" then
		return
	end
	refresh(player)
	local entry = data.Quests.List[index]
	local quest = entry and questsById[entry.Id]
	if not quest or entry.Claimed or entry.Progress < entry.Goal then
		return
	end
	entry.Claimed = true
	local text = EconomyService:GrantReward(player, quest.Reward, true)
	Net:Notify(player, "Quest reward: " .. text, "success")
	Net:Fire(player, "Sfx", "Cash")
	Net:Fire(player, "Fx", "Confetti")
	sync(player)
end

function QuestService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function QuestService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		refresh(player)
		sync(player)
	end)
	Net:On("ClaimQuest", claim, 2, 4)

	-- Roll over to new quests at midnight UTC for players who stay online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local data = DataService:GetData(player)
				if data and data.Quests.Day ~= today() then
					refresh(player)
					sync(player)
				end
			end
		end
	end)
end

return QuestService
