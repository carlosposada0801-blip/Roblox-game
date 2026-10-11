--[[
	DevCommands (Studio only)
	Chat commands for testing. Main only loads this module when
	RunService:IsStudio() is true, so they never exist in a live server.

	  /cash <amount>   add cash (default 1000)
	  /save            force a save right now
	  /unlockall       unlock every tycoon item for free
	  /wipe            reset your data to a new player's and kick you
	  /help            list commands
]]

local Players = game:GetService("Players")

local DevCommands = {}

function DevCommands:Init(services)
	local DataService = services.DataService
	local EconomyService = services.EconomyService
	local TycoonService = services.TycoonService

	local commands = {}

	commands["/cash"] = function(player, args)
		local amount = tonumber(args[2]) or 1000
		EconomyService:AddCash(player, amount)
		print(("[Dev] Gave %s $%d (now $%d)"):format(player.Name, amount, EconomyService:GetCash(player)))
	end

	commands["/save"] = function(player)
		local ok = DataService:SaveAsync(player)
		print(("[Dev] Save for %s: %s"):format(player.Name, ok and "OK" or "FAILED"))
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

	commands["/wipe"] = function(player)
		DataService:ResetData(player)
		player:Kick("[Dev] Your data was wiped. Press Play again.")
	end

	commands["/help"] = function()
		print("[Dev] Commands: /cash <amount>, /save, /unlockall, /wipe, /help")
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
