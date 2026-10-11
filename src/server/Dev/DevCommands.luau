--[[
	DevCommands (Studio only)
	Chat commands for testing and admin. They work for everyone in Studio,
	and in a live game only for the game's creator and AdminConfig.Admins.

	  /cash <amount>     add cash (default 1000)
	  /robots <amount>   add robots for hiring workers (default 10)
	  /unlockall         unlock every tycoon item for free
	  /prototype         your next robot off the line is a Prototype
	  /pass <name>       grant a game pass: DoubleCash, AutoCollect, FasterConveyors, VIPFloor
	  /buy <name>        run a developer product through ProcessReceipt's grant code:
	                     SmallCash, MediumCash, LargeCash, NextUpgrade, Prototype
	  /rebirths <n>      set your rebirth count (try 2 to unlock the 2nd floor)
	  /event <id>        start an event: PowerSurge, GoldenRain, Malfunction, CashFrenzy, RobotParade
	  /pet <type>        get a pet: Bolt, Gear, Spark, Nova, Pulse, Omega, Celestia
	  /daily             make today's daily reward claimable again
	  /quests            finish all of today's quests
	  /balance [rebirths] print the economy timeline (how long each purchase takes)
	  /boss [countdown]  start a boss raid now (or with the 60s warning countdown)
	  /drones            send rogue drones to your factory
	  /battle            start a robot battle now (vs another player if one is queued, else a Training Bot)
	  /boost <id> [min]  give a boost: CashX2, Turbo, Lucky
	  /offer             show the Starter Pack popup
	  /sky               unlock the Sky Factory (sets rebirths if needed)
	  /save              force a save right now
	  /wipe              reset your data to a new player's and kick you
	  /help              list commands
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.AdminConfig)
local BalanceModel = require(ReplicatedStorage.Shared.Util.BalanceModel)

local function isAdmin(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId or table.find(AdminConfig.Admins, player.UserId) ~= nil
end

local DevCommands = {}

function DevCommands:Init(services)
	local DataService = services.DataService
	local EconomyService = services.EconomyService
	local TycoonService = services.TycoonService
	local ProductionService = services.ProductionService
	local MonetizationService = services.MonetizationService
	local EventService = services.EventService
	local PetService = services.PetService
	local QuestService = services.QuestService

	local commands = {}

	commands["/cash"] = function(player, args)
		local amount = tonumber(args[2]) or 1000
		EconomyService:AddCash(player, amount)
		print(("[Dev] Gave %s $%d (now $%d)"):format(player.Name, amount, EconomyService:GetCash(player)))
	end

	commands["/robots"] = function(player, args)
		EconomyService:AddStat(player, "Robots", tonumber(args[2]) or 10)
		print("[Dev] Robots now", player:GetAttribute("Robots"))
	end

	commands["/unlockall"] = function(player)
		local count = 0
		local available = TycoonService:GetAvailableItems(player)
		while #available > 0 do
			local before = count
			for _, item in ipairs(available) do
				if TycoonService:GrantItem(player, item.Id) then
					count += 1
				end
			end
			if count == before then
				break
			end
			available = TycoonService:GetAvailableItems(player)
		end
		print(("[Dev] Unlocked %d item(s) for %s"):format(count, player.Name))
	end

	commands["/prototype"] = function(player)
		ProductionService:ForcePrototype(player)
		print("[Dev] The next robot built will be a Prototype (needs Final Assembly)")
	end

	commands["/pass"] = function(player, args)
		local ok = MonetizationService:DevGrantPass(player, args[2] or "")
		print(ok and ("[Dev] Granted pass " .. args[2]) or "[Dev] Unknown pass. Try DoubleCash, AutoCollect, FasterConveyors, VIPFloor")
	end

	commands["/buy"] = function(player, args)
		local result = MonetizationService:DevBuyProduct(player, args[2] or "")
		print(result and ("[Dev] Product result: " .. tostring(result)) or "[Dev] Unknown product. Try SmallCash, MediumCash, LargeCash, NextUpgrade, Prototype")
	end

	commands["/rebirths"] = function(player, args)
		local data = DataService:GetData(player)
		data.Rebirths = math.max(0, math.floor(tonumber(args[2]) or 2))
		EconomyService:Refresh(player)
		services.TycoonService:ResetTycoon(player)
		print("[Dev] Rebirths set to", data.Rebirths)
	end

	commands["/event"] = function(_, args)
		print(EventService:StartEvent(args[2] or "") and "[Dev] Event started" or "[Dev] Unknown event. Try PowerSurge, GoldenRain, Malfunction, CashFrenzy, RobotParade")
	end

	commands["/pet"] = function(player, args)
		print(PetService:GivePet(player, args[2] or "") and "[Dev] Pet added" or "[Dev] Unknown pet or inventory full")
	end

	commands["/daily"] = function(player)
		local data = DataService:GetData(player)
		data.Daily.LastDay = 0
		player:SetAttribute("DailyAvailable", true)
		print("[Dev] Daily reward is claimable again (rejoin to see the popup)")
	end

	commands["/quests"] = function(player)
		local data = DataService:GetData(player)
		local QuestConfig = require(game:GetService("ReplicatedStorage").Shared.Config.QuestConfig)
		for _, entry in ipairs(data.Quests.List) do
			for _, quest in ipairs(QuestConfig.Pool) do
				if quest.Id == entry.Id then
					QuestService:Track(player, quest.Stat, entry.Goal)
				end
			end
		end
	end

	commands["/balance"] = function(_, args)
		print(BalanceModel.report(tonumber(args[2]) or 0))
	end

	commands["/boss"] = function(_, args)
		if args[2] == "countdown" then
			services.BossService:Countdown(10)
		else
			services.BossService:Spawn()
		end
	end

	commands["/battle"] = function(player)
		local data = DataService:GetData(player)
		if data.Prototypes < 1 then
			services.EconomyService:AddStat(player, "Prototypes", 1)
		end
		local other
		for _, candidate in ipairs(Players:GetPlayers()) do
			local candidateData = candidate ~= player and DataService:GetData(candidate)
			if candidateData and candidateData.Prototypes > 0 then
				other = candidate
				break
			end
		end
		services.BattleService:DevStart(player, other)
	end

	commands["/boost"] = function(player, args)
		print(services.BoostService:Give(player, args[2] or "CashX2", tonumber(args[3]) or 5) and "[Dev] Boost given" or "[Dev] Unknown boost. Try CashX2, Turbo, Lucky")
	end

	commands["/offer"] = function(player)
		services.Net:Fire(player, "ShowOffer", "StarterPack")
	end

	commands["/sky"] = function(player)
		if services.SkyService then
			services.SkyService:DevUnlock(player)
		end
	end

	commands["/drones"] = function(player)
		services.DefenseService:SpawnRaid(player)
	end

	commands["/save"] = function(player)
		local ok = DataService:SaveAsync(player)
		print(("[Dev] Save for %s: %s"):format(player.Name, ok and "OK" or "FAILED"))
	end

	commands["/wipe"] = function(player)
		DataService:ResetData(player)
		player:Kick("[Dev] Your data was wiped. Press Play again.")
	end

	commands["/help"] = function()
		print("[Dev] Commands: /cash, /robots, /unlockall, /prototype, /pass, /buy, /rebirths, /event, /pet, /daily, /quests, /balance, /boss, /drones, /battle, /boost, /offer, /sky, /save, /wipe, /help")
	end

	local function hook(player)
		player.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			local command = commands[string.lower(args[1])]
			if command and isAdmin(player) and DataService:GetProfile(player) then
				command(player, args)
			end
		end)
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	print("[Dev] Studio dev commands enabled. Type /help in chat.")
end

return DevCommands
