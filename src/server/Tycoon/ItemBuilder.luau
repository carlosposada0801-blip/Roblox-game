--[[
	ItemBuilder
	Turns an ItemConfig entry into a Model on a plot: either a copy of
	ServerStorage.TycoonItems[<Id>] if you made a custom model, or parts built
	from the entry's Parts list.
]]

local ServerStorage = game:GetService("ServerStorage")

local ItemBuilder = {}

-- Keys in a part definition that are handled here instead of set as properties
local SPECIAL_KEYS = { CFrame = true, Light = true }

local function buildPart(definition, plotCFrame)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(definition) do
		if not SPECIAL_KEYS[key] then
			part[key] = value
		end
	end

	part.CFrame = plotCFrame * (definition.CFrame or CFrame.identity)

	if definition.Light then
		local light = Instance.new("PointLight")
		for key, value in pairs(definition.Light) do
			light[key] = value
		end
		light.Parent = part
	end

	return part
end

local function addLabel(model, text)
	local anchor = model.PrimaryPart
	if not anchor then
		return
	end
	local center, size = model:GetBoundingBox()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.MaxDistance = 120
	billboard.AlwaysOnTop = false
	billboard.Adornee = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	-- Center the label over the whole model, not just the first part
	billboard.StudsOffsetWorldSpace = center.Position - anchor.Position + Vector3.new(0, size.Y / 2 + 2, 0)
	billboard.Parent = anchor
end

-- Builds the item and parents it to the plot's Items folder.
function ItemBuilder.build(item, plot)
	local model
	local templates = ServerStorage:FindFirstChild("TycoonItems")
	local template = templates and templates:FindFirstChild(item.Id)

	if template then
		model = template:Clone()
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		model:PivotTo(plot.CFrame * (item.Pivot or CFrame.identity))
	else
		model = Instance.new("Model")
		for _, definition in ipairs(item.Parts or {}) do
			local part = buildPart(definition, plot.CFrame)
			part.Parent = model
			if not model.PrimaryPart then
				model.PrimaryPart = part
			end
		end
	end

	model.Name = item.Id
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Category", item.Category)

	if item.Label then
		addLabel(model, item.DisplayName)
	end

	model.Parent = plot.Model.Items
	return model
end

return ItemBuilder
