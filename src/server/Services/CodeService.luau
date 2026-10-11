--[[
	CodeService
	Promo codes (CodesConfig). The client sends RedeemCode(text); the server
	checks it and answers with CodeResult(ok, message):
	  valid -> reward given, saved in data.RedeemedCodes so it works once
	  unknown code, expired code, already used -> a clear message, nothing given
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CodesConfig = require(Shared.Config.CodesConfig)
local Time = require(Shared.Util.Time)

local DataService, EconomyService, Net

local CodeService = {}

local codes = {} -- [UPPERCASE CODE] = config
for name, code in pairs(CodesConfig.Codes) do
	codes[string.upper(name)] = code
end

local function reply(player, ok, message)
	Net:Fire(player, "CodeResult", ok, message)
	Net:Notify(player, message, if ok then "success" else "error")
end

local function redeem(player, text)
	local data = DataService:GetData(player)
	if not data or type(text) ~= "string" then
		return
	end
	local name = string.upper((string.gsub(string.sub(text, 1, 40), "%s", "")))
	local code = codes[name]
	if name == "" or not code then
		reply(player, false, "❌ That code doesn't exist. Check the spelling!")
		return
	end
	if code.Expires and os.time() >= Time.fromDate(code.Expires.Year, code.Expires.Month, code.Expires.Day) then
		reply(player, false, "⌛ The code " .. name .. " has expired.")
		return
	end
	if data.RedeemedCodes[name] then
		reply(player, false, "You already used " .. name .. ".")
		return
	end

	data.RedeemedCodes[name] = os.time()
	local text2 = EconomyService:GrantReward(player, code.Reward, code.ScaleCash)
	reply(player, true, "🎉 Code " .. name .. " redeemed: " .. text2 .. "!")
	Net:Fire(player, "Sfx", "Rebirth")
	Net:Fire(player, "Fx", "Confetti")
	task.spawn(DataService.SaveAsync, DataService, player)
end

function CodeService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	Net = services.Net
end

function CodeService:Start()
	-- Slow rate limit so codes can't be guessed by spamming
	Net:On("RedeemCode", redeem, 0.5, 3)
end

return CodeService
