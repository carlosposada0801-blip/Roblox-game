--[[
	EventService
	Server-wide factory events (EventConfig). One event at a time; the
	active event is published as workspace attributes so every client can
	show a banner:
	  Event        = event id ("" when none)
	  EventEndsAt  = workspace:GetServerTimeNow() when it ends
	Other services ask GetValue(key, default) for the active event's settings.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.EventConfig)

local EconomyService, Net

local EventService = {}
EventService.Changed = require(ReplicatedStorage.Shared.Util.Signal).new()

local active -- event config table or nil
local activeId = ""
local activeToken = 0 -- so an old event's timer can't end a newer event

function EventService:GetActive()
	return activeId, active
end

function EventService:GetValue(key: string, default)
	if active and active[key] ~= nil then
		return active[key]
	end
	return default
end

local function refreshPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService:Refresh(player)
	end
end

function EventService:StartEvent(id: string)
	local event = EventConfig.Events[id]
	if not event then
		return false
	end
	active, activeId = event, id
	activeToken += 1
	local token = activeToken
	workspace:SetAttribute("Event", id)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + EventConfig.Duration)
	Net:NotifyAll(event.DisplayName .. "! " .. event.Description, "special")
	Net:FireAll("Sfx", "Rebirth")
	refreshPlayers()
	self.Changed:Fire(id)

	task.delay(EventConfig.Duration, function()
		if activeToken == token then
			active, activeId = nil, ""
			workspace:SetAttribute("Event", "")
			refreshPlayers()
			self.Changed:Fire("")
		end
	end)
	return true
end

function EventService:Init(services)
	EconomyService = services.EconomyService
	Net = services.Net
	workspace:SetAttribute("Event", "")
end

function EventService:Start()
	task.spawn(function()
		task.wait(EventConfig.FirstDelay)
		local ids = {}
		for id in pairs(EventConfig.Events) do
			table.insert(ids, id)
		end
		table.sort(ids)
		while true do
			if #Players:GetPlayers() > 0 then
				self:StartEvent(ids[math.random(#ids)])
			end
			task.wait(EventConfig.Duration + math.random(EventConfig.Interval[1], EventConfig.Interval[2]))
		end
	end)
end

return EventService
