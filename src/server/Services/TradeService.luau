--[[
	TradeService
	Safe trades of robots and Prototypes between two players.
	  1. A sends TradeRequest(B's UserId). B gets an invite and answers TradeRespond.
	  2. Both set offers with TradeOffer(robots, prototypes). Any change un-readies both.
	  3. Both press Ready. A countdown runs; any change or cancel stops it.
	  4. The server re-checks both players still own their offer, then swaps
	     both sides in memory and saves both players.
	Each client receives TradeState(table) whenever something changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TradeConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TradeConfig)

local DataService, EconomyService, Net

local TradeService = {}

local invites = {} -- [target] = { From = player, Expires = os.clock() }
local trades = {} -- [player] = trade
-- trade = { A, B, Offers = { [player] = { Robots, Prototypes } }, Ready = { [player] = bool }, Countdown = number?, Id }

local nextId = 0

local function other(trade, player)
	return if trade.A == player then trade.B else trade.A
end

local function sendState(trade)
	for _, player in ipairs({ trade.A, trade.B }) do
		local partner = other(trade, player)
		Net:Fire(player, "TradeState", {
			Active = true,
			PartnerName = partner.DisplayName,
			MyOffer = trade.Offers[player],
			TheirOffer = trade.Offers[partner],
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
	return data ~= nil and data.Robots >= offer.Robots and data.Prototypes >= offer.Prototypes
end

local function complete(trade)
	local a, b = trade.A, trade.B
	local offerA, offerB = trade.Offers[a], trade.Offers[b]
	if not (owns(a, offerA) and owns(b, offerB)) then
		endTrade(trade, "Trade cancelled: someone no longer has what they offered.")
		return
	end

	-- Swap both sides
	EconomyService:AddStat(a, "Robots", offerB.Robots - offerA.Robots)
	EconomyService:AddStat(a, "Prototypes", offerB.Prototypes - offerA.Prototypes)
	EconomyService:AddStat(b, "Robots", offerA.Robots - offerB.Robots)
	EconomyService:AddStat(b, "Prototypes", offerA.Prototypes - offerB.Prototypes)

	endTrade(trade)
	for _, player in ipairs({ a, b }) do
		Net:Notify(player, "✅ Trade complete!", "success")
		Net:Fire(player, "Sfx", "Purchase")
		task.spawn(DataService.SaveAsync, DataService, player)
	end
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
		Offers = { [from] = { Robots = 0, Prototypes = 0 }, [player] = { Robots = 0, Prototypes = 0 } },
		Ready = {},
		Version = 0,
	}
	trades[from], trades[player] = trade, trade
	sendState(trade)
end

local function offer(player, robots, prototypes)
	local trade = trades[player]
	local data = DataService:GetData(player)
	if not (trade and data) or type(robots) ~= "number" or type(prototypes) ~= "number" then
		return
	end
	robots = math.clamp(math.floor(robots), 0, data.Robots)
	prototypes = math.clamp(math.floor(prototypes), 0, data.Prototypes)
	trade.Offers[player] = { Robots = robots, Prototypes = prototypes }
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
	Net = services.Net
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
