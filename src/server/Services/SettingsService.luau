--[[
	SettingsService
	Saved player preferences (DataConfig.Template.Settings), such as the
	guide arrow. Mirrored to the client as attributes Setting_<key>.
	Only keys that exist in the template, with a matching value type, are accepted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DataConfig)

local DataService, PlayerService, Net

local SettingsService = {}

local DEFAULTS = DataConfig.Template.Settings

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	for key in pairs(DEFAULTS) do
		player:SetAttribute("Setting_" .. key, data.Settings[key])
	end
end

local function setSetting(player, key, value)
	local data = DataService:GetData(player)
	if not data or type(key) ~= "string" or DEFAULTS[key] == nil or type(value) ~= type(DEFAULTS[key]) then
		return
	end
	data.Settings[key] = value
	sync(player)
end

function SettingsService:Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService
	Net = services.Net
end

function SettingsService:Start()
	PlayerService.PlayerReady:Connect(sync)
	Net:On("SetSetting", setSetting, 2, 4)
end

return SettingsService
