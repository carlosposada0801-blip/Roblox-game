--[[
	Signal
	A small event object so services can talk to each other without
	requiring one another in a loop.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	local handlers = self._handlers
	table.insert(handlers, handler)

	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in ipairs(table.clone(self._handlers)) do
		task.spawn(handler, ...)
	end
end

return Signal
