--[[
	BalanceModel
	Estimates how long a new player waits for each purchase, using the real
	configs (ItemConfig, RarityConfig, RebirthConfig). Used by the admin
	/balance command so prices can be tuned with numbers instead of guesses.

	Model: income per second = sum over droppers of value / interval, times
	the multiplier of every machine on that dropper's floor that accepts its
	stage. Robots also get the average rarity multiplier. Ignores upgrades,
	workers, pets and events (so real players are a bit faster).
]]

local Config = script.Parent.Parent.Config
local ItemConfig = require(Config.ItemConfig)
local RarityConfig = require(Config.RarityConfig)
local RebirthConfig = require(Config.RebirthConfig)

local BalanceModel = {}

local STAGE_ORDER = { Scrap = 1, Metal = 2, RobotPart = 3, Robot = 4 }

local function averageRarity()
	local total, weighted = 0, 0
	for _, rarity in ipairs(RarityConfig.Rarities) do
		total += rarity.Weight
		weighted += rarity.Weight * rarity.ValueMultiplier
	end
	return weighted / total
end

-- Which floor an item is on, from the height of its first part
local function floorOf(item)
	local first = item.Parts and item.Parts[1]
	local y = first and first.CFrame and first.CFrame.Y or 0
	if y > 30 then
		return 3
	elseif y > 14 then
		return 2
	end
	return 1
end

-- Income per second for a set of owned items
function BalanceModel.income(owned, rebirths)
	local rarity = averageRarity()
	local total = 0
	for _, item in ipairs(ItemConfig.Items) do
		if owned[item.Id] and item.Dropper and not item.GamePass and not item.World then
			local stage = item.Dropper.Stage or "Scrap"
			local value = item.Dropper.Value / item.Dropper.Interval
			local floor = floorOf(item)
			-- Machines along the line, in the order items pass them (config order)
			for _, machine in ipairs(ItemConfig.Items) do
				local config = machine.Machine
				if owned[machine.Id] and config and floorOf(machine) == floor and table.find(config.Accepts, stage) then
					value *= config.Multiplier or 1
					if config.Output and STAGE_ORDER[config.Output] > STAGE_ORDER[stage] then
						stage = config.Output
					end
					if config.Output == "Robot" then
						value *= rarity
					end
				end
			end
			total += value
		end
	end
	return total * RebirthConfig.GetMultiplier(rebirths or 0)
end

-- Simulates a player buying the cheapest available item each time.
-- Returns a list of { Item, Price, WaitSeconds, TotalSeconds, IncomeAfter }.
function BalanceModel.timeline(rebirths)
	rebirths = rebirths or 0
	local owned, steps, clock = {}, {}, 0
	while true do
		local best
		for _, item in ipairs(ItemConfig.Items) do
			-- Sky Factory items are a separate progression, not part of the rebirth loop
			if not owned[item.Id] and not item.GamePass and not item.World and rebirths >= (item.MinRebirths or 0) then
				local ready = true
				for _, required in ipairs(item.Requires or {}) do
					ready = ready and owned[required] == true
				end
				if ready and (not best or item.Price < best.Price) then
					best = item
				end
			end
		end
		if not best then
			break
		end
		local income = BalanceModel.income(owned, rebirths)
		local wait = if best.Price == 0 then 0 elseif income > 0 then best.Price / income else math.huge
		clock += wait
		owned[best.Id] = true
		table.insert(steps, {
			Item = best.Id,
			Price = best.Price,
			WaitSeconds = wait,
			TotalSeconds = clock,
			IncomeAfter = BalanceModel.income(owned, rebirths),
		})
	end
	local rebirthCost = RebirthConfig.GetCost(rebirths)
	local finalIncome = BalanceModel.income(owned, rebirths)
	return steps, clock + rebirthCost / math.max(finalIncome, 1e-6)
end

function BalanceModel.report(rebirths)
	local steps, toRebirth = BalanceModel.timeline(rebirths)
	local lines = { ("Balance at %d rebirths (cheapest-first buying):"):format(rebirths or 0) }
	for _, step in ipairs(steps) do
		table.insert(lines, ("  %-18s $%-10d wait %6.0fs   total %5.1f min   income %.0f/s"):format(step.Item, step.Price, step.WaitSeconds, step.TotalSeconds / 60, step.IncomeAfter))
	end
	table.insert(lines, ("  -> next rebirth after about %.1f min"):format(toRebirth / 60))
	return table.concat(lines, "\n")
end

return BalanceModel
