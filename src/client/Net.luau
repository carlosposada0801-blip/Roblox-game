--[[
	Client side of the remotes. Sends requests and listens to server messages.
	The server rate limits and validates everything sent from here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}

function Net.Fire(name: string, ...)
	remotes:WaitForChild(name):FireServer(...)
end

function Net.On(name: string, handler)
	return remotes:WaitForChild(name).OnClientEvent:Connect(handler)
end

return Net
