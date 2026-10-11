--[[
	DevCommands (Studio only)
	Chat commands for testing. Main only loads this module when
	RunService:IsStudio() is true, so they never exist in a live server.

	  /cash <amount>     add cash (default 1000)
	  /robots <amount>   add robots for hiring workers (default 10)
	  /unlockall         unlock every tycoon item for free
	  /prototype         your next robot off the line is a Prototype
	  /pass <name>       grant a game pass: DoubleCash, AutoCollect, FasterConveyors, VIPFloor
	  /buy <name>        run a developer product through ProcessReceipt's grant code:
	                     SmallCash, MediumCash, LargeCash, NextUpgrade, Prototype
	  /save              force a save right now
	  /wipe              reset your data to a new player's and kick you
	  /help              list commands
]]

local Players = game:GetService("Players")

local DevCommands = {}

function DevCommands:Init(services)
	local DataService = services.DataService
	local EconomyService = services.EconomyService
	local TycoonService = services.TycoonService
	local ProductionService = services.ProductionService
	local MonetizationService = services.MonetizationService

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

	commands["/save"] = function(player)
		local ok = DataService:SaveAsync(player)
		print(("[Dev] Save for %s: %s"):format(player.Name, ok and "OK" or "FAILED"))
	end

	commands["/wipe"] = function(player)
		DataService:ResetData(player)
		player:Kick("[Dev] Your data was wiped. Press Play again.")
	end

	commands["/help"] = function()
		print("[Dev] Commands: /cash, /robots, /unlockall, /prototype, /pass <name>, /buy <name>, /save, /wipe, /help")
	end

	local function hook(player)
		player.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			local command = commands[string.lower(args[1])]
			if command and DataService:GetProfile(player) then
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
