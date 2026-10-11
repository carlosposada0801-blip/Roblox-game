--[[
	TradeService
	Safe trades of robots, Prototypes and tradable cosmetics (robot skins
	marked Tradable in CosmeticConfig) between two players.
	  1. A sends TradeRequest(B's UserId). B gets an invite and answers TradeRespond.
	  2. Both set offers with TradeOffer(robots, prototypes, { cosmeticIds }).
	     Any change un-readies both.
	  3. Both press Ready. A 5-second countdown runs; any change or cancel stops it.
	  4. The server re-checks both players still own their offer, swaps both
	     sides in memory, saves BOTH players right away (the session lock in
	     DataService means no other server can hold an older copy), and logs
	     the trade (output + the TradeLog DataStore).
	Each client receives TradeState(table) whenever something changes.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TradeConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TradeConfig)

local DataService, EconomyService, CosmeticService, Net

local MAX_COSMETICS = 6
local tradeLog -- DataStore, or nil in Studio without API access

local TradeService = {}

local invites = {} -- [target] = { From = player, Expires = os.clock() }
local trades = {} -- [player] = trade
-- trade = { A, B, Offers = { [player] = { Robots, Prototypes } }, Ready = { [player] = bool }, Countdown = number?, Id }

local nextId = 0

local function other(trade, player)
	return if trade.A == player then trade.B else trade.A
end

local function describe(offer)
	local names = {}
	for _, id in ipairs(offer.Cosmetics) do
		table.insert(names, CosmeticService:GetName(id))
	end
	return { Robots = offer.Robots, Prototypes = offer.Prototypes, Cosmetics = offer.Cosmetics, CosmeticNames = names }
end

local function sendState(trade)
	for _, player in ipairs({ trade.A, trade.B }) do
		local partner = other(trade, player)
		Net:Fire(player, "TradeState", {
			Active = true,
			PartnerName = partner.DisplayName,
			MyOffer = describe(trade.Offers[player]),
			TheirOffer = describe(trade.Offers[partner]),
			MyReady = trade.Ready[player] == true,
			TheirReady = trade.Ready[partner] == true,
			Countdown = trade.Countdown,
		})
	end
end

local function endTrade(trade, reason)
	for _, player in ipairs({ trade.A, trade.B }) do
		if trades[player] == trade then
			trades[player] = nil
			if player.Parent then
				Net:Fire(player, "TradeState", { Active = false })
				if reason then
					Net:Notify(player, reason, "info")
				end
			end
		end
	end
end

local function owns(player, offer)
	local data = DataService:GetData(player)
	if not data or data.Robots < offer.Robots or data.Prototypes < offer.Prototypes then
		return false
	end
	for _, id in ipairs(offer.Cosmetics) do
		if not CosmeticService:IsTradable(player, id) then
			return false
		end
	end
	return true
end


local function logTrade(trade, offerA, offerB)
	local record = {
		Time = os.time(),
		Server = game.JobId,
		A = trade.A.UserId,
		B = trade.B.UserId,
		AGave = describe(offerA),
		BGave = describe(offerB),
	}
	print("[Trade] " .. HttpService:JSONEncode(record))
	if tradeLog then
		task.spawn(pcall, function()
			tradeLog:SetAsync(("%d_%d_%s"):format(record.Time, trade.Id, string.sub(game.JobId, 1, 8)), record)
		end)
	end
end

local function complete(trade)
	local a, b = trade.A, trade.B
	local offerA, offerB = trade.Offers[a], trade.Offers[b]
	if not (owns(a, offerA) and owns(b, offerB)) then
		endTrade(trade, "Trade cancelled: someone no longer has what they offered.")
		return
	end

	-- Swap both sides (all in memory, no yields in between)
	EconomyService:AddStat(a, "Robots", offerB.Robots - offerA.Robots)
	EconomyService:AddStat(a, "Prototypes", offerB.Prototypes - offerA.Prototypes)
	EconomyService:AddStat(b, "Robots", offerA.Robots - offerB.Robots)
	EconomyService:AddStat(b, "Prototypes", offerA.Prototypes - offerB.Prototypes)
	for _, id in ipairs(offerA.Cosmetics) do
		CosmeticService:TakeCosmetic(a, id)
	end
	for _, id in ipairs(offerB.Cosmetics) do
		CosmeticService:TakeCosmetic(b, id)
	end
	for _, id in ipairs(offerA.Cosmetics) do
		CosmeticService:GiveSkin(b, id)
	end
	for _, id in ipairs(offerB.Cosmetics) do
		CosmeticService:GiveSkin(a, id)
	end
	EconomyService:AddStat(a, "Trades", 1)
	EconomyService:AddStat(b, "Trades", 1)

	endTrade(trade)
	logTrade(trade, offerA, offerB)
	for _, player in ipairs({ a, b }) do
		Net:Notify(player, "✅ Trade complete!", "success")
		Net:Fire(player, "Sfx", "Purchase")
	end
	-- Save both right away
	task.spawn(DataService.SaveAsync, DataService, a)
	DataService:SaveAsync(b)
end

local function unready(trade)
	trade.Ready = {}
	trade.Countdown = nil
	trade.Version += 1
end

local function request(player, targetUserId)
	if type(targetUserId) ~= "number" or trades[player] then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or trades[target] then
		Net:Notify(player, "That player can't trade right now.", "error")
		return
	end
	invites[target] = { From = player, Expires = os.clock() + TradeConfig.InviteTimeout }
	Net:Fire(target, "TradeInvite", player.UserId, player.DisplayName)
	Net:Notify(player, "Trade request sent to " .. target.DisplayName .. ".", "info")
end

local function respond(player, fromUserId, accept)
	local invite = invites[player]
	invites[player] = nil
	if not invite or type(fromUserId) ~= "number" or invite.From.UserId ~= fromUserId or os.clock() > invite.Expires then
		return
	end
	local from = invite.From
	if not accept then
		Net:Notify(from, player.DisplayName .. " declined your trade.", "info")
		return
	end
	if trades[from] or trades[player] or not from.Parent then
		return
	end
	nextId += 1
	local trade = {
		Id = nextId,
		A = from,
		B = player,
		Offers = { [from] = { Robots = 0, Prototypes = 0, Cosmetics = {} }, [player] = { Robots = 0, Prototypes = 0, Cosmetics = {} } },
		Ready = {},
		Version = 0,
	}
	trades[from], trades[player] = trade, trade
	sendState(trade)
end

local function offer(player, robots, prototypes, cosmetics)
	local trade = trades[player]
	local data = DataService:GetData(player)
	if not (trade and data) or type(robots) ~= "number" or type(prototypes) ~= "number" or robots ~= robots or prototypes ~= prototypes then
		return
	end
	robots = math.clamp(math.floor(robots), 0, data.Robots)
	prototypes = math.clamp(math.floor(prototypes), 0, data.Prototypes)
	-- Only tradable cosmetics the player owns, no duplicates
	local list, seen = {}, {}
	if type(cosmetics) == "table" then
		for _, id in ipairs(cosmetics) do
			if #list >= MAX_COSMETICS then
				break
			end
			if type(id) == "string" and not seen[id] and CosmeticService:IsTradable(player, id) then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	trade.Offers[player] = { Robots = robots, Prototypes = prototypes, Cosmetics = list }
	unready(trade)
	sendState(trade)
end

local function setReady(player, ready)
	local trade = trades[player]
	if not trade or type(ready) ~= "boolean" then
		return
	end
	if not ready then
		unready(trade)
		sendState(trade)
		return
	end
	trade.Ready[player] = true
	if trade.Ready[trade.A] and trade.Ready[trade.B] then
		trade.Countdown = TradeConfig.ConfirmCountdown
		local version = trade.Version
		task.spawn(function()
			for remaining = TradeConfig.ConfirmCountdown, 1, -1 do
				if trades[trade.A] ~= trade or trade.Version ~= version then
					return
				end
				trade.Countdown = remaining
				sendState(trade)
				task.wait(1)
			end
			if trades[trade.A] == trade and trade.Version == version then
				complete(trade)
			end
		end)
	else
		sendState(trade)
	end
end

local function cancel(player)
	local trade = trades[player]
	if trade then
		endTrade(trade, player.DisplayName .. " cancelled the trade.")
	end
end

function TradeService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	CosmeticService = services.CosmeticService
	Net = services.Net
	if not DataService.IsMock then
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, TradeConfig.LogStore)
		tradeLog = if ok then store else nil
	end
end

function TradeService:Start()
	Net:On("TradeRequest", request, 0.5, 2)
	Net:On("TradeRespond", respond, 1, 2)
	Net:On("TradeOffer", offer, 4, 8)
	Net:On("TradeReady", setReady, 2, 4)
	Net:On("TradeCancel", cancel, 2, 4)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		cancel(player)
	end)
end

return TradeService
