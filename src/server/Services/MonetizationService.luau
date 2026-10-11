--[[
	MonetizationService
	Game passes and developer products (IDs in MonetizationConfig).

	Game passes
	  * Ownership is checked on join and stored as the attribute Pass_<key>.
	    Other systems read that attribute (2x cash, auto-collect, belt speed, VIP floor).
	  * A purchase made in-game applies immediately.

	Developer products: ProcessReceipt never loses or doubles a purchase
	  1. Player not in this server, or data not loaded yet -> NotProcessedYet
	     (Roblox retries later, e.g. when they rejoin).
	  2. PurchaseId already in data.ProcessedReceipts -> PurchaseGranted (no second grant).
	  3. Grant the reward, record the PurchaseId in the same save data, then save.
	     Only return PurchaseGranted once that save succeeds. If it fails, Roblox
	     retries, and step 2 stops a second grant because the record is in memory.
	  The session lock in DataService guarantees no other server edits this
	  player's data at the same time.

	Studio: while an ID is 0 (placeholder), buying it simulates the purchase
	through the same grant code, so the whole shop can be tested.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, TycoonService, Net

local MonetizationService = {}

local passKeyById = {}
local productById = {}

local function warnPlaceholders()
	local missing = {}
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.Id == 0 then
			table.insert(missing, "pass " .. key)
		else
			passKeyById[pass.Id] = key
		end
	end
	for key, product in pairs(MonetizationConfig.Products) do
		product.Key = key
		if product.Id == 0 then
			table.insert(missing, "product " .. key)
		elseif productById[product.Id] then
			warn(("[Monetization] Products %s and %s share ID %d"):format(productById[product.Id].Key, key, product.Id))
		else
			productById[product.Id] = product
		end
	end
	if #missing > 0 then
		warn("[Monetization] Placeholder IDs (0) for: " .. table.concat(missing, ", ") .. ". Set them in MonetizationConfig.")
	end
end

-- Game passes ----------------------------------------------------------------

local function applyPass(player, key)
	if player:GetAttribute("Pass_" .. key) then
		return
	end
	player:SetAttribute("Pass_" .. key, true)
	-- EconomyService and ProductionService react to the attribute; the VIP floor is an item.
	TycoonService:RefreshPassItems(player)
end

-- Yields. Called by PlayerService before the tycoon is built.
function MonetizationService:LoadPasses(player: Player)
	local data = DataService:GetData(player)
	player:SetAttribute("StarterPackBought", data ~= nil and data.StarterPackBought)
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
			elseif not ok then
				warn(("[Monetization] Couldn't check pass %s for %s: %s"):format(key, player.Name, tostring(owns)))
			end
		end
	end
end

-- Developer products ---------------------------------------------------------

local function grantProduct(player, product)
	local data = DataService:GetData(player)

	if product.Kind == "Cash" then
		local amount = product.Amount
		if MonetizationConfig.CashPacksScaleWithRebirths then
			amount *= RebirthConfig.GetMultiplier(data.Rebirths)
		end
		assert(EconomyService:AddCash(player, amount), "AddCash failed")
		Net:Notify(player, ("Thanks! +%s"):format(Format.cash(amount)), "success")
		Net:Fire(player, "CashPopup", math.floor(amount))
	elseif product.Kind == "NextUpgrade" then
		local nextItem = TycoonService:GetAvailableItems(player)[1]
		if nextItem and TycoonService:GrantItem(player, nextItem.Id) then
			Net:Notify(player, ("Thanks! Unlocked %s."):format(nextItem.DisplayName), "success")
		else
			assert(EconomyService:AddCash(player, product.FallbackCash), "AddCash failed")
			Net:Notify(player, ("Everything's unlocked, so here's %s instead!"):format(Format.cash(product.FallbackCash)), "success")
		end
	elseif product.Kind == "StarterPack" then
		-- Granted every time it's bought (Roblox can't stop a re-purchase), but the shop hides it after the first
		local text = EconomyService:GrantReward(player, product.Reward, false)
		data.StarterPackBought = true
		player:SetAttribute("StarterPackBought", true)
		Net:Notify(player, "Thanks! Starter Pack: " .. text .. "!", "success")
		Net:Fire(player, "Fx", "Confetti")
	elseif product.Kind == "Prototype" then
		EconomyService:AddStat(player, "Prototypes", 1)
		Net:Notify(player, "Thanks! You unlocked a ★ PROTOTYPE ★ robot. Take it to the arena!", "special")
	else
		error("Unknown product kind " .. tostring(product.Kind))
	end
end

local function pruneReceipts(data)
	local entries = {}
	for purchaseId, time in pairs(data.ProcessedReceipts) do
		table.insert(entries, { Id = purchaseId, Time = time })
	end
	if #entries <= MonetizationConfig.ReceiptHistorySize then
		return
	end
	table.sort(entries, function(a, b)
		return a.Time > b.Time
	end)
	for index = MonetizationConfig.ReceiptHistorySize + 1, #entries do
		data.ProcessedReceipts[entries[index].Id] = nil
	end
end

-- Shared by real receipts and Studio simulations.
local function handlePurchase(player, purchaseId, product)
	-- Wait briefly for data if they're still loading in
	local deadline = os.clock() + 10
	while not DataService:GetProfile(player) and player.Parent and os.clock() < deadline do
		task.wait(0.5)
	end

	local profile = DataService:GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = profile.Data
	if data.ProcessedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, err = pcall(grantProduct, player, product)
	if not ok then
		warn(("[Monetization] Granting %s to %s failed: %s"):format(product.Key, player.Name, tostring(err)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.ProcessedReceipts[purchaseId] = os.time()
	pruneReceipts(data)

	if not DataService:SaveAsync(player) then
		-- The grant and receipt are in memory and will be saved later; Roblox
		-- will retry and step 2 returns PurchaseGranted without granting again.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print(("[Monetization] %s bought %s (%s)"):format(player.Name, product.Key, purchaseId))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] Receipt for unknown product ID " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return handlePurchase(player, receipt.PurchaseId, product)
end

-- Purchase requests ----------------------------------------------------------

local function requestPurchase(player, kind, key)
	if type(kind) ~= "string" or type(key) ~= "string" then
		return
	end

	if kind == "Pass" then
		local pass = MonetizationConfig.GamePasses[key]
		if not pass then
			return
		elseif player:GetAttribute("Pass_" .. key) then
			Net:Notify(player, "You already own " .. pass.DisplayName .. ".", "info")
		elseif pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		elseif RunService:IsStudio() then
			applyPass(player, key)
			Net:Notify(player, "[Studio] Simulated pass: " .. pass.DisplayName, "success")
		else
			Net:Notify(player, pass.DisplayName .. " isn't on sale yet.", "error")
		end
	elseif kind == "Product" then
		local product = MonetizationConfig.Products[key]
		if not product then
			return
		elseif product.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		elseif RunService:IsStudio() then
			local fakePurchaseId = "studio-" .. HttpService:GenerateGUID(false)
			local result = handlePurchase(player, fakePurchaseId, product)
			print("[Monetization] Studio simulated product", key, result)
		else
			Net:Notify(player, product.DisplayName .. " isn't on sale yet.", "error")
		end
	end
end

function MonetizationService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	TycoonService = services.TycoonService
	Net = services.Net
	warnPlaceholders()
end

function MonetizationService:Start()
	-- Must be assigned exactly once, by one script.
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			applyPass(player, key)
			Net:Notify(player, "Thanks! " .. MonetizationConfig.GamePasses[key].DisplayName .. " is active.", "success")
		end
	end)

	Net:On("RequestPurchase", requestPurchase, 1, 2)
	Players.PlayerMembershipChanged:Connect(function(player)
		EconomyService:Refresh(player)
	end)
end

-- Studio dev commands
function MonetizationService:DevGrantPass(player: Player, key: string): boolean
	if MonetizationConfig.GamePasses[key] then
		applyPass(player, key)
		return true
	end
	return false
end

function MonetizationService:DevBuyProduct(player: Player, key: string)
	local product = MonetizationConfig.Products[key]
	if product then
		return handlePurchase(player, "studio-" .. HttpService:GenerateGUID(false), product)
	end
	return nil
end

return MonetizationService
