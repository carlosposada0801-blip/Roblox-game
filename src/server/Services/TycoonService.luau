--[[
	TycoonService
	Buy buttons and unlocking.

	  * A button appears once every item in its Requires list is owned.
	  * Stepping on a button asks the server to buy it. The server checks the
	    owner, the requirements and the price, then takes the cash, saves the
	    unlock, builds the item, and shows any buttons that are now available.
	  * When a player joins, everything in their saved Unlocked list is rebuilt
	    for free, so the tycoon looks exactly like they left it.
	  * Items with a GamePass field have no button. They are built whenever the
	    player owns that pass (attribute Pass_<key>, set by MonetizationService).
	  * ResetTycoon clears every bought item (used by rebirths).

	Later steps listen to ItemUnlocked to give items behavior (droppers,
	conveyors, machines...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared.Config.ItemConfig)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local ItemBuilder = require(script.Parent.Parent.Tycoon.ItemBuilder)

local DataService, EconomyService, PlotService, PlayerService, Net

local TOUCH_COOLDOWN = 0.75 -- seconds between purchase attempts on one button

local TycoonService = {}
TycoonService.ItemUnlocked = Signal.new() -- (player, plot, item, model, isRebuild)
TycoonService.TycoonReset = Signal.new() -- (player, plot)

local items = {} -- valid config entries, in config order
local itemsById = {}
local state = {} -- [Player] = { Plot, Buttons = { [itemId] = Model }, LastTouch = { [itemId] = number } }

-- Config checks ------------------------------------------------------------

local function validateConfig()
	local buttonSpots = {}

	for index, item in ipairs(ItemConfig.Items) do
		local problem
		if type(item.Id) ~= "string" or item.Id == "" then
			problem = "missing Id"
		elseif itemsById[item.Id] then
			problem = "duplicate Id"
		elseif type(item.Price) ~= "number" or item.Price < 0 then
			problem = "Price must be a number >= 0"
		elseif typeof(item.Button) ~= "Vector3" and not item.GamePass then
			problem = "Button must be a Vector3"
		end

		if problem then
			warn(("[ItemConfig] Skipping entry #%d (%s): %s"):format(index, tostring(item.Id), problem))
		else
			item.Requires = item.Requires or {}
			itemsById[item.Id] = item
			table.insert(items, item)

			if item.Button then
				local spot = tostring(item.Button)
				if buttonSpots[spot] then
					warn(("[ItemConfig] %s and %s use the same Button position"):format(buttonSpots[spot], item.Id))
				end
				buttonSpots[spot] = item.Id
			end
		end
	end

	for _, item in ipairs(items) do
		for _, requiredId in ipairs(item.Requires) do
			if not itemsById[requiredId] then
				warn(("[ItemConfig] %s requires unknown item '%s', so it can never unlock"):format(item.Id, requiredId))
			end
		end
	end

	-- Anything that can't be reached from the free starter items is a typo or a loop.
	local reachable, changed = {}, true
	while changed do
		changed = false
		for _, item in ipairs(items) do
			if not reachable[item.Id] then
				local ok = true
				for _, requiredId in ipairs(item.Requires) do
					ok = ok and reachable[requiredId] == true
				end
				if ok then
					reachable[item.Id] = true
					changed = true
				end
			end
		end
	end
	for _, item in ipairs(items) do
		if not reachable[item.Id] then
			warn(("[ItemConfig] %s can never be unlocked (check its Requires for a loop)"):format(item.Id))
		end
	end
end

-- Helpers --------------------------------------------------------------------

local function requirementsMet(data, item)
	for _, requiredId in ipairs(item.Requires) do
		if not data.Unlocked[requiredId] then
			return false
		end
	end
	return true
end

-- Can this item be bought with cash right now?
local function isAvailable(data, item)
	return not item.GamePass and not data.Unlocked[item.Id] and requirementsMet(data, item)
end

local function makeText(parent, text, position, size, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = parent
	return label
end

-- Buttons -----------------------------------------------------------------

local function createButton(player, playerState, item)
	local plot = playerState.Plot
	local origin = plot.CFrame * CFrame.new(item.Button)

	local model = Instance.new("Model")
	model.Name = "Button_" .. item.Id
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Price", item.Price)

	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Anchored = true
	rim.Size = Vector3.new(5.6, 0.3, 5.6)
	rim.CFrame = origin * CFrame.new(0, 0.15, 0)
	rim.Color = Color3.fromRGB(30, 30, 35)
	rim.Material = Enum.Material.Metal
	rim.Parent = model

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.CanCollide = false -- so the player sinks onto it and Touched fires reliably
	pad.Size = Vector3.new(4.6, 0.5, 4.6)
	pad.CFrame = origin * CFrame.new(0, 0.4, 0)
	pad.Color = Color3.fromRGB(60, 220, 100)
	pad.Material = Enum.Material.Neon
	pad.Parent = model
	model.PrimaryPart = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromOffset(180, 60)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.MaxDistance = 60
	billboard.Parent = pad

	makeText(billboard, item.DisplayName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55), Color3.new(1, 1, 1))
	local priceText = if item.Price == 0 then "FREE" else Format.cash(item.Price)
	makeText(billboard, priceText, UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.45), Color3.fromRGB(120, 255, 140)).Name =
		"Price"

	pad.Touched:Connect(function(hit)
		if state[player] ~= playerState then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		if not character or Players:GetPlayerFromCharacter(character) ~= player then
			return -- only the plot owner can buy here
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local now = os.clock()
		if now - (playerState.LastTouch[item.Id] or 0) < TOUCH_COOLDOWN then
			return
		end
		playerState.LastTouch[item.Id] = now

		local ok, reason = TycoonService:TryPurchase(player, item.Id)
		if ok then
			Net:Fire(player, "Sfx", "Purchase")
		elseif reason == "TooExpensive" then
			-- The client flashes the button red when this changes
			model:SetAttribute("Denied", (model:GetAttribute("Denied") or 0) + 1)
			Net:Fire(player, "Sfx", "Denied")
		end
	end)

	model.Parent = plot.Model.Buttons
	playerState.Buttons[item.Id] = model
end

-- Shows every button whose requirements are met and that isn't showing yet.
local function refreshButtons(player)
	local playerState = state[player]
	local data = DataService:GetData(player)
	if not (playerState and data) then
		return
	end

	for _, item in ipairs(items) do
		if isAvailable(data, item) and not playerState.Buttons[item.Id] then
			createButton(player, playerState, item)
		end
	end
end

local function unlock(player, item, isRebuild)
	local playerState = state[player]
	local data = DataService:GetData(player)
	if not (playerState and data) then
		return
	end

	-- Pass items are never saved: owning the pass is what builds them.
	if not item.GamePass then
		data.Unlocked[item.Id] = true
	end

	local button = playerState.Buttons[item.Id]
	if button then
		button:Destroy()
		playerState.Buttons[item.Id] = nil
	end

	local model = ItemBuilder.build(item, playerState.Plot)
	TycoonService.ItemUnlocked:Fire(player, playerState.Plot, item, model, isRebuild)
end

-- Builds pass items the player owns that aren't built yet.
local function buildPassItems(player)
	local playerState = state[player]
	if not playerState then
		return
	end
	for _, item in ipairs(items) do
		if
			item.GamePass
			and player:GetAttribute("Pass_" .. item.GamePass)
			and not playerState.Plot.Model.Items:FindFirstChild(item.Id)
		then
			unlock(player, item, true)
		end
	end
end

-- Player setup / teardown --------------------------------------------------

local function setupPlayer(player, _profile, plot)
	local data = DataService:GetData(player)
	if not data or PlotService:GetPlot(player) ~= plot then
		return -- the player left before setup ran
	end

	state[player] = { Plot = plot, Buttons = {}, LastTouch = {} }

	-- Rebuild owned items in config order
	local rebuilt = 0
	for _, item in ipairs(items) do
		if data.Unlocked[item.Id] and not item.GamePass then
			unlock(player, item, true)
			rebuilt += 1
		end
	end

	buildPassItems(player)
	refreshButtons(player)
	print(("[TycoonService] Rebuilt %d item(s) for %s"):format(rebuilt, player.Name))
end

-- Public API ---------------------------------------------------------------

function TycoonService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlotService = services.PlotService
	PlayerService = services.PlayerService
	Net = services.Net
	validateConfig()
end

function TycoonService:Start()
	PlayerService.PlayerReady:Connect(setupPlayer)
	PlotService.PlotReleased:Connect(function(player)
		state[player] = nil
	end)
end

-- Returns true, or false plus a reason: "NotReady" | "UnknownItem" | "Owned" | "Locked" | "TooExpensive"
function TycoonService:TryPurchase(player: Player, itemId: string)
	local data = DataService:GetData(player)
	local item = itemsById[itemId]
	if not (data and state[player]) then
		return false, "NotReady"
	elseif not item then
		return false, "UnknownItem"
	elseif data.Unlocked[itemId] then
		return false, "Owned"
	elseif not requirementsMet(data, item) then
		return false, "Locked"
	elseif not EconomyService:TrySpend(player, item.Price) then
		return false, "TooExpensive"
	end

	unlock(player, item, false)
	refreshButtons(player)
	return true
end

-- Unlocks an available item without charging (dev products, dev commands).
function TycoonService:GrantItem(player: Player, itemId: string): boolean
	local data = DataService:GetData(player)
	local item = itemsById[itemId]
	if not (data and item and state[player]) or not isAvailable(data, item) then
		return false
	end

	unlock(player, item, false)
	refreshButtons(player)
	return true
end

-- Items the player could buy right now, cheapest first.
function TycoonService:GetAvailableItems(player: Player)
	local data = DataService:GetData(player)
	local available = {}
	if not data then
		return available
	end

	for _, item in ipairs(items) do
		if isAvailable(data, item) then
			table.insert(available, item)
		end
	end
	table.sort(available, function(a, b)
		return a.Price < b.Price
	end)
	return available
end

-- Builds any pass items after a game pass purchase.
function TycoonService:RefreshPassItems(player: Player)
	buildPassItems(player)
end

-- Removes every bought item and button and starts the plot over (rebirth).
function TycoonService:ResetTycoon(player: Player)
	local playerState = state[player]
	local data = DataService:GetData(player)
	if not (playerState and data) then
		return
	end

	data.Unlocked = {}
	playerState.Buttons = {}
	playerState.LastTouch = {}

	local plotModel = playerState.Plot.Model
	plotModel.Items:ClearAllChildren()
	plotModel.Buttons:ClearAllChildren()
	plotModel.Drops:ClearAllChildren()

	self.TycoonReset:Fire(player, playerState.Plot)

	buildPassItems(player)
	refreshButtons(player)
end

function TycoonService:GetItem(itemId: string)
	return itemsById[itemId]
end

function TycoonService:GetItems()
	return items
end

return TycoonService
