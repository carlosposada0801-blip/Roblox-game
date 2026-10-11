--[[
	Server entry point. Requires every service, then calls Init on each
	(in order) and Start on each. Init wires up references; Start begins
	listening for players and running loops.

	To add a new service: create it in Services/ and add it to SERVICE_ORDER.
]]

local RunService = game:GetService("RunService")

local Services = script.Parent.Services

local SERVICE_ORDER = {
	"Net",
	"SceneryService",
	"DataService",
	"PlotService",
	"EconomyService",
	"TycoonService",
	"WorkerService",
	"ProductionService",
	"RebirthService",
	"MonetizationService",
	"ArenaService",
	"PlayerService", -- keep last: it starts loading players
}

local services = {}
for _, name in ipairs(SERVICE_ORDER) do
	services[name] = require(Services[name])
end

-- Each step is protected, so one broken service can't stop the others from loading.
local function run(name, method)
	local service = services[name]
	if service[method] then
		local ok, err = pcall(service[method], service, services)
		if not ok then
			warn(("[RobotFactoryTycoon] %s:%s failed: %s"):format(name, method, tostring(err)))
		end
	end
end

for _, name in ipairs(SERVICE_ORDER) do
	run(name, "Init")
end

if RunService:IsStudio() then
	require(script.Parent.Dev.DevCommands):Init(services)
end

for _, name in ipairs(SERVICE_ORDER) do
	run(name, "Start")
end

print("[RobotFactoryTycoon] Server started")
