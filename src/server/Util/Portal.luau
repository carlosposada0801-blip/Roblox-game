--[[
	Portal
	A glowing pad with an arch and a floating label. Touching it calls
	onTouch(player) (at most once every 2 seconds per player).
]]

local Players = game:GetService("Players")

local Portal = {}

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

function Portal.label(parentPart, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 50)
	billboard.StudsOffset = Vector3.new(0, height or 6, 0)
	billboard.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Sarpanch
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = billboard
	billboard.Parent = parentPart
	return label
end

-- position = world position of the pad's center on the ground
function Portal.create(name, position, color, text, parent, onTouch, withArch)
	local pad = part({
		Name = name,
		Size = Vector3.new(10, 0.6, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
	if withArch ~= false then
		for _, x in ipairs({ -5.5, 5.5 }) do
			part({ Size = Vector3.new(1.5, 12, 1.5), CFrame = CFrame.new(position + Vector3.new(x, 6, 0)), Color = Color3.fromRGB(45, 47, 52), Material = Enum.Material.Metal }, parent)
		end
		part({ Size = Vector3.new(12.5, 1.5, 1.5), CFrame = CFrame.new(position + Vector3.new(0, 12.5, 0)), Color = color, Material = Enum.Material.Neon }, parent)
	end
	Portal.label(pad, text, color, if withArch == false then 5 else 15)

	local last = {}
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if os.clock() - (last[player] or 0) < 2 then
			return
		end
		last[player] = os.clock()
		onTouch(player)
	end)
	return pad
end

-- Moves a player's character, loading the area first (streaming)
function Portal.teleport(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	pcall(player.RequestStreamAroundAsync, player, cframe.Position, 5)
	if player.Character == character then
		character:PivotTo(cframe)
	end
end

return Portal
