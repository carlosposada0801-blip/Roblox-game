--[[
	ContractService
	Timed jobs (ContractConfig). Each player gets 3 offers; accept one and
	finish it before the timer ends for a big reward. Progress comes from
	the same stats as quests (QuestService forwards Track calls here).
	Attribute ContractJson = { Offers, Active, CooldownUntil }
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ContractConfig = require(Shared.Config.ContractConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlayerService, Net

local ContractService = {}

local states = {} -- [Player] = { Offers = {config...}, Active = { Config, Progress, EndsAt }, CooldownUntil }

local function describe(config)
	local goal = if config.Stat == "CashEarned" then Format.abbreviate(config.Goal) else config.Goal
	return config.Text:format(goal)
end

local function rollOffers(state)
	local pool = table.clone(ContractConfig.Offers)
	state.Offers = {}
	for _ = 1, math.min(3, #pool) do
		table.insert(state.Offers, table.remove(pool, math.random(#pool)))
	end
end

local function sync(player)
	local state = states[player]
	if not state then
		return
	end
	local view = { Offers = {}, CooldownUntil = state.CooldownUntil }
	for _, offer in ipairs(state.Offers) do
		table.insert(view.Offers, { Text = describe(offer), Time = offer.Time, Reward = offer.Reward })
	end
	if state.Active then
		view.Active = {
			Text = describe(state.Active.Config),
			Progress = math.floor(state.Active.Progress),
			Goal = state.Active.Config.Goal,
			EndsAt = state.Active.EndsAt,
			Reward = state.Active.Config.Reward,
		}
	end
	player:SetAttribute("ContractJson", HttpService:JSONEncode(view))
end

function ContractService:Track(player: Player, stat: string, amount: number?)
	local state = states[player]
	local active = state and state.Active
	if not active or active.Config.Stat ~= stat then
		return
	end
	active.Progress = math.min(active.Config.Goal, active.Progress + (amount or 1))
	if active.Progress >= active.Config.Goal then
		local data = DataService:GetData(player)
		state.Active = nil
		state.CooldownUntil = workspace:GetServerTimeNow() + ContractConfig.Cooldown
		rollOffers(state)
		if data then
			data.ContractsDone += 1
			local text = EconomyService:GrantReward(player, active.Config.Reward, true)
			Net:Notify(player, "📜 Contract complete! " .. text, "special")
			Net:Fire(player, "Sfx", "Rebirth")
			Net:Fire(player, "Fx", "Confetti")
		end
	end
	sync(player)
end

local function contractAction(player, action, index)
	local state = states[player]
	if not state then
		return
	end
	if action == "Accept" then
		if state.Active or type(index) ~= "number" or workspace:GetServerTimeNow() < state.CooldownUntil then
			return
		end
		local offer = state.Offers[index]
		if not offer then
			return
		end
		state.Active = { Config = offer, Progress = 0, EndsAt = workspace:GetServerTimeNow() + offer.Time }
		Net:Notify(player, "📜 Contract accepted: " .. describe(offer), "info")
	elseif action == "Abandon" then
		if state.Active then
			state.Active = nil
			state.CooldownUntil = workspace:GetServerTimeNow() + ContractConfig.Cooldown
			rollOffers(state)
		end
	end
	sync(player)
end

function ContractService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	Net = services.Net
end

function ContractService:Start()
	PlayerService.PlayerReady:Connect(function(player)
		local state = { CooldownUntil = 0 }
		rollOffers(state)
		states[player] = state
		sync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	Net:On("ContractAction", contractAction, 2, 4)

	-- Expire contracts that ran out of time
	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for player, state in pairs(states) do
				if state.Active and now >= state.Active.EndsAt then
					state.Active = nil
					state.CooldownUntil = now + ContractConfig.Cooldown
					rollOffers(state)
					Net:Notify(player, "⏰ Contract failed: time ran out.", "error")
					sync(player)
				end
			end
		end
	end)
end

return ContractService
