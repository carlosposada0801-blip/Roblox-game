--[[
	Client entry point. Starts each controller in Controllers/.
	Controllers only display state and send requests; the server decides everything.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local CONTROLLER_ORDER = {
	"HudController",
	"ButtonController",
}

for _, name in ipairs(CONTROLLER_ORDER) do
	local controller = require(Controllers:WaitForChild(name))
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
