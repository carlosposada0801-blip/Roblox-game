--[[
	Net
	Creates every RemoteEvent listed in Shared.Remotes and wraps incoming
	client events with:
	  * a per-player rate limit (extra calls are dropped)
	  * a check that the player's data has loaded
	  * pcall, so a bad request can't break the handler for everyone

	Handlers must still validate their arguments: anything from the client
	can be any type.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Net = {}

local remotes = {}
local limiters = {}

function Net:Init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in ipairs(RemoteNames) do
		local remote = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
end

function Net:Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in pairs(limiters) do
			limiter:Remove(player)
		end
	end)
end

-- rate = calls per second, burst = how many can be made at once
function Net:On(name: string, handler, rate: number?, burst: number?)
	local remote = assert(remotes[name], "Unknown remote " .. name)
	local limiter = RateLimiter.new(rate or 2, burst or 3)
	limiters[name] = limiter

	remote.OnServerEvent:Connect(function(player, ...)
		if not limiter:Allow(player) then
			return
		end
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end

		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s handler failed for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net:Fire(player: Player, name: string, ...)
	remotes[name]:FireClient(player, ...)
end

function Net:FireAll(name: string, ...)
	remotes[name]:FireAllClients(...)
end

-- Shortcut for toast messages. kind: "info" | "success" | "error" | "special"
function Net:Notify(player: Player, text: string, kind: string?)
	remotes.Notify:FireClient(player, text, kind or "info")
end

function Net:NotifyAll(text: string, kind: string?)
	remotes.Notify:FireAllClients(text, kind or "info")
end

return Net
