--[[
	PromptController
	Shows each player only the prompts that make sense for them:
	  OwnerOnly prompts (Upgrade) are hidden on other players' plots.
	  NotOwner prompts (Like) are shown on other players' plots only.
	Changing Enabled here only affects this player's screen.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local likePrompts = {} -- NotOwner prompts, re-checked as plot owners change

local function plotOwnerOf(instance)
	local current = instance
	while current and current ~= workspace do
		if current:GetAttribute("PlotId") then
			return current:GetAttribute("OwnerId") or 0
		end
		current = current.Parent
	end
	return 0
end

local function apply(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	if prompt:GetAttribute("OwnerOnly") then
		if prompt:GetAttribute("OwnerId") ~= player.UserId then
			prompt.Enabled = false
		end
	elseif prompt:GetAttribute("NotOwner") then
		likePrompts[prompt] = true
		local owner = plotOwnerOf(prompt)
		prompt.Enabled = owner ~= 0 and owner ~= player.UserId
	end
end

function PromptController:Start()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		apply(descendant)
	end
	workspace.DescendantAdded:Connect(function(descendant)
		task.defer(apply, descendant)
	end)
	-- Plot owners change as players come and go
	while true do
		task.wait(2)
		for prompt in pairs(likePrompts) do
			if prompt.Parent then
				apply(prompt)
			else
				likePrompts[prompt] = nil
			end
		end
	end
end

return PromptController
