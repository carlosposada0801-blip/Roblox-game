--[[
	Client entry point. Starts each controller in Controllers/.
	Controllers only display state and send requests; the server decides everything.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local CONTROLLER_ORDER = {
	"NotificationController", -- first, so others can show toasts
	"SoundController",
	"EffectsController",
	"HudController",
	"EventController",
	"ButtonController",
	"MenuController",
	"ArenaController",
	"GuideController",
	"PromptController",
	"ArrowController",
	"PetController",
	"TradeController",
	"WeaponController",
	"EnvironmentController",
	"MusicController",
}

local controllers = {}
for _, name in ipairs(CONTROLLER_ORDER) do
	controllers[name] = require(Controllers:WaitForChild(name))
end

for _, name in ipairs(CONTROLLER_ORDER) do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(controller.Start, controller, controllers)
	end
end
