--[[
	RateLimiter
	Token bucket: each key gets `burst` tokens that refill at `rate` per
	second. Every allowed call spends one token.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(rate: number, burst: number?)
	return setmetatable({
		Rate = rate,
		Burst = burst or math.max(1, rate),
		Buckets = {},
	}, RateLimiter)
end

function RateLimiter:Allow(key): boolean
	local now = os.clock()
	local bucket = self.Buckets[key]
	if not bucket then
		bucket = { Tokens = self.Burst, Last = now }
		self.Buckets[key] = bucket
	end

	bucket.Tokens = math.min(self.Burst, bucket.Tokens + (now - bucket.Last) * self.Rate)
	bucket.Last = now

	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Remove(key)
	self.Buckets[key] = nil
end

return RateLimiter
