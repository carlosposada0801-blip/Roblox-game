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

return Format
