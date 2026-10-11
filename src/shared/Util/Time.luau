--[[
	Time
	UTC calendar helpers shared by daily rewards, quests, codes and the
	weekly leaderboard. All of them use os.time(), which is UTC on Roblox.
]]

local Time = {}

local DAY = 86400

-- Days since 1 Jan 1970 (UTC). Changes at UTC midnight.
function Time.day(now: number?): number
	return (now or os.time()) // DAY
end

-- Weeks since the epoch, starting on Mondays at UTC midnight.
-- (1 Jan 1970 was a Thursday, so Monday 5 Jan 1970 starts week 1.)
function Time.week(now: number?): number
	return (Time.day(now) + 3) // 7
end

-- Unix time when the given week (from Time.week) ends.
function Time.weekEnds(week: number): number
	return ((week + 1) * 7 - 3) * DAY
end

-- Unix time of midnight UTC on a calendar date (days-from-civil algorithm).
function Time.fromDate(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yearOfEra = y - era * 400
	local monthIndex = (month + 9) % 12
	local dayOfYear = (153 * monthIndex + 2) // 5 + day - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	return (era * 146097 + dayOfEra - 719468) * DAY
end

-- "1h 05m" / "12m 30s" / "45s"
function Time.format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return ("%dh %02dm"):format(seconds // 3600, seconds % 3600 // 60)
	elseif seconds >= 60 then
		return ("%dm %02ds"):format(seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

return Time
