--[[
	PetService
	Hatch drone pets from eggs (PetConfig), equip up to MaxEquipped, and
	they add their Bonus to your cash multiplier. Pets are drawn by every
	client from the attribute EquippedPets ("Bolt,Gear,...").
	Inventory is mirrored as PetsJson for the Pets menu.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared.Config.PetConfig)
local Format = require(Shared.Util.Format)

local DataService, EconomyService, PlayerService, QuestService, Net

local PetService = {}

local eggsById = {}
for _, egg in ipairs(PetConfig.Eggs) do
	eggsById[egg.Id] = egg
end

local function equippedCount(data)
	local count = 0
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

function PetService:GetMultiplier(player: Player): number
	local data = DataService:GetData(player)
	local bonus = 0
	if data then
		for _, pet in ipairs(data.Pets) do
			local info = PetConfig.Pets[pet.Type]
			if pet.Equipped and info then
				bonus += info.Bonus
			end
		end
	end
	return 1 + bonus
end

local function sync(player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	local equipped = {}
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			table.insert(equipped, pet.Type)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(equipped, ","))
	player:SetAttribute("PetsJson", HttpService:JSONEncode(data.Pets))
	EconomyService:Refresh(player)
end

local function rollPet(egg)
	local total = 0
	for _, entry in ipairs(egg.Pets) do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in ipairs(egg.Pets) do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Pet
		end
	end
	return egg.Pets[1].Pet
end

-- Adds a pet (also used by dev commands). Returns the pet type or nil if full.
function PetService:GivePet(player: Player, petType: string)
	local data = DataService:GetData(player)
	if not data or not PetConfig.Pets[petType] or #data.Pets >= PetConfig.MaxInventory then
		return nil
	end
	local pet = { Id = data.NextPetId, Type = petType, Equipped = equippedCount(data) < PetConfig.MaxEquipped }
	data.NextPetId += 1
	table.insert(data.Pets, pet)
	sync(player)
	return petType
end

local function hatch(player, eggId)
	local egg = type(eggId) == "string" and eggsById[eggId]
	local data = DataService:GetData(player)
	if not (egg and data) then
		return
	end
	if egg.Season and workspace:GetAttribute("Season") ~= egg.Season then
		Net:Notify(player, egg.DisplayName .. " is only available during its season.", "error")
		return
	end
	if #data.Pets >= PetConfig.MaxInventory then
		Net:Notify(player, "Your pet inventory is full. Delete a pet first.", "error")
		return
	end
	if not EconomyService:TrySpend(player, egg.Price) then
		Net:Notify(player, ("%s costs %s."):format(egg.DisplayName, Format.cash(egg.Price)), "error")
		Net:Fire(player, "Sfx", "Denied")
		return
	end
	local petType = PetService:GivePet(player, rollPet(egg))
	QuestService:Track(player, "EggsHatched", 1)
	Net:Fire(player, "PetHatched", petType, egg.Id)
	local info = PetConfig.Pets[petType]
	if info.Rarity == "Legendary" or info.Rarity == "Mythic" then
		Net:NotifyAll(("%s hatched a %s %s!"):format(player.DisplayName, info.Rarity, info.DisplayName), "special")
	end
end

local function petAction(player, action, petId)
	local data = DataService:GetData(player)
	if not data or type(action) ~= "string" or type(petId) ~= "number" then
		return
	end
	local index, pet
	for i, p in ipairs(data.Pets) do
		if p.Id == petId then
			index, pet = i, p
			break
		end
	end
	if not pet then
		return
	end

	if action == "Equip" then
		if equippedCount(data) >= PetConfig.MaxEquipped then
			Net:Notify(player, ("You can only equip %d pets."):format(PetConfig.MaxEquipped), "error")
			return
		end
		pet.Equipped = true
	elseif action == "Unequip" then
		pet.Equipped = false
	elseif action == "Delete" then
		table.remove(data.Pets, index)
	else
		return
	end
	sync(player)
end

function PetService:Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	PlayerService = services.PlayerService
	QuestService = services.QuestService
	Net = services.Net
end

function PetService:Start()
	PlayerService.PlayerReady:Connect(sync)
	Net:On("HatchEgg", hatch, 1, 2)
	Net:On("PetAction", petAction, 4, 8)
end

return PetService
