--[[
	CoopService
	Invite friends to build your factory with you. Builders can step on
	your buy buttons (paid from YOUR cash) and collect your cash pad (into
	YOUR cash). Up to MaxBuilders per plot; ends when either player leaves.
	Remotes: CoopInvite(userId), CoopRespond(fromUserId, accept), CoopLeave()
	Attributes: player "BuildingFor" (owner UserId), plot model "Builders" ("id,id")
]]

local Players = game:GetService("Players")

local PlotService, Net

local CoopService = {}

local MAX_BUILDERS = 2
local invites = {} -- [target] = { From, Expires }
local builders = {} -- [owner] = { Player, ... }

local function syncPlot(owner)
	local plot = PlotService:GetPlot(owner)
	if not plot then
		return
	end
	local ids = {}
	for _, builder in ipairs(builders[owner] or {}) do
		table.insert(ids, tostring(builder.UserId))
	end
	plot.Model:SetAttribute("Builders", table.concat(ids, ","))
end

-- Is this player allowed to build on the owner's plot?
function CoopService:CanBuild(player: Player, owner: Player): boolean
	if player == owner then
		return true
	end
	return table.find(builders[owner] or {}, player) ~= nil
end

local function removeBuilder(builder)
	local ownerId = builder:GetAttribute("BuildingFor")
	if not ownerId then
		return
	end
	builder:SetAttribute("BuildingFor", nil)
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner and builders[owner] then
		local index = table.find(builders[owner], builder)
		if index then
			table.remove(builders[owner], index)
		end
		syncPlot(owner)
		Net:Notify(owner, builder.DisplayName .. " stopped building with you.", "info")
	end
end

local function invite(owner, targetUserId)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == owner or not PlotService:GetPlot(owner) then
		return
	end
	if #(builders[owner] or {}) >= MAX_BUILDERS then
		Net:Notify(owner, "Your factory already has the maximum number of builders.", "error")
		return
	end
	invites[target] = { From = owner, Expires = os.clock() + 20 }
	Net:Fire(target, "CoopInviteReceived", owner.UserId, owner.DisplayName)
	Net:Notify(owner, "Build invite sent to " .. target.DisplayName .. ".", "info")
end

local function respond(target, fromUserId, accept)
	local pending = invites[target]
	invites[target] = nil
	if not pending or pending.From.UserId ~= fromUserId or os.clock() > pending.Expires or not accept then
		return
	end
	local owner = pending.From
	if not owner.Parent or #(builders[owner] or {}) >= MAX_BUILDERS then
		return
	end
	removeBuilder(target)
	builders[owner] = builders[owner] or {}
	table.insert(builders[owner], target)
	target:SetAttribute("BuildingFor", owner.UserId)
	syncPlot(owner)
	Net:Notify(owner, "🤝 " .. target.DisplayName .. " is now building your factory with you!", "success")
	Net:Notify(target, "🤝 You're building " .. owner.DisplayName .. "'s factory! Purchases use their cash.", "success")
	local plot = PlotService:GetPlot(owner)
	if plot and target.Character then
		target.Character:PivotTo(plot.SpawnCFrame * CFrame.new(4, 0, 0))
	end
end

function CoopService:Init(services)
	PlotService = services.PlotService
	Net = services.Net
end

function CoopService:Start()
	Net:On("CoopInvite", invite, 0.5, 2)
	Net:On("CoopRespond", respond, 1, 2)
	Net:On("CoopLeave", removeBuilder, 1, 2)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		removeBuilder(player)
		for _, builder in ipairs(builders[player] or {}) do
			builder:SetAttribute("BuildingFor", nil)
			if builder.Parent then
				Net:Notify(builder, player.DisplayName .. " left, so your co-op session ended.", "info")
			end
		end
		builders[player] = nil
	end)
end

return CoopService
