--[[
	Format
	Number formatting shared by the server (signs, billboards) and client (UI).
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.abbreviate(value: number): string
	if value ~= value then
		return "0"
	end

	local sign = if value < 0 then "-" else ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end

	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (tier * 3)
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")

	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.cash(value: number): string
	return "$" .. Format.abbreviate(value)
end

-- Short text for a reward table: "💵 $5K  🤖 3  ⚡ 2x Cash 10m"
-- (BoostConfig is looked up lazily so Format stays dependency-free.)
function Format.reward(reward, separator: string?): string
	local parts = {}
	if reward.Cash then
		table.insert(parts, "💵 " .. Format.cash(reward.Cash))
	end
	if reward.Robots then
		table.insert(parts, "🤖 " .. reward.Robots)
	end
	if reward.Prototypes then
		table.insert(parts, "⭐ Rare Prototype")
	end
	if reward.Boost then
		local BoostConfig = require(script.Parent.Parent.Config.BoostConfig)
		local boost = BoostConfig.Boosts[reward.Boost.Id]
		if boost then
			table.insert(parts, ("%s %s %dm"):format(boost.Icon, boost.Name, reward.Boost.Minutes))
		end
	end
	if reward.Skin then
		table.insert(parts, "🎨 Robot skin")
	end
	return table.concat(parts, separator or "  ")
end

return Format
