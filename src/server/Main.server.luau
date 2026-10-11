--[[
	Server entry point. Requires every service, then calls Init on each
	(in order) and Start on each. Init wires up references; Start begins
	listening for players and running loops.

	To add a new service: create it in Services/ and add it to SERVICE_ORDER.
]]

local RunService = game:GetService("RunService")

local Services = script.Parent.Services

local SERVICE_ORDER = {
	"DataService",
	"PlotService",
	"EconomyService",
	"PlayerService", -- keep last: it starts loading players
}

local services = {}
for _, name in ipairs(SERVICE_ORDER) do
	services[name] = require(Services[name])
end

for _, name in ipairs(SERVICE_ORDER) do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end

if RunService:IsStudio() then
	require(script.Parent.Dev.DevCommands):Init(services)
end

for _, name in ipairs(SERVICE_ORDER) do
	local service = services[name]
	if service.Start then
		service:Start()
	end
end

print("[RobotFactoryTycoon] Server started")
