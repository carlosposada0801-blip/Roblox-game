--[[
	PlayerService
	Runs the join and leave sequence in the right order:

	  join:  load data (session lock) -> claim plot -> check game passes
	         -> leaderstats -> teleport -> PlayerReady (tycoon, workers, ...)
	  leave: release plot -> save and release data

	Later steps hook into PlayerReady to rebuild the player's tycoon.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local DataService, PlotService, EconomyService, MonetizationService

local PlayerService = {}
PlayerService.PlayerReady = Signal.new() -- (player, profile, plot)

local function onPlayerAdded(player: Player)
	local profile = DataService:LoadAsync(player)
	if not profile or player.Parent == nil then
		return
	end

	local plot = PlotService:ClaimPlot(player)
	if not plot then
		player:Kick("All factories on this server are taken. Please join another server.")
		return
	end

	MonetizationService:LoadPasses(player)
	if player.Parent == nil then
		return
	end

	EconomyService:SetupPlayer(player)

	player.CharacterAdded:Connect(function()
		PlotService:TeleportToPlot(player)
	end)
	if player.Character then
		task.spawn(PlotService.TeleportToPlot, PlotService, player)
	end

	player:SetAttribute("DataLoaded", true)
	print(("[PlayerService] %s loaded into plot %d"):format(player.Name, plot.Id))
	PlayerService.PlayerReady:Fire(player, profile, plot)
end

local function onPlayerRemoving(player: Player)
	PlotService:ReleasePlot(player)
	DataService:Release(player)
end

function PlayerService:Init(services)
	DataService = services.DataService
	PlotService = services.PlotService
	EconomyService = services.EconomyService
	MonetizationService = services.MonetizationService
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Players who joined before this script finished starting up
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

function PlayerService:IsReady(player: Player): boolean
	return player:GetAttribute("DataLoaded") == true
end

return PlayerService
