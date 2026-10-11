--[[
	TradeConfig
	Player-to-player trades of robots, Prototypes and tradable cosmetics. Both players must
	press Ready; then a countdown runs, and any change cancels the ready
	state. The server checks both sides still have what they offered
	before swapping.
]]

return {
	InviteTimeout = 20,
	ConfirmCountdown = 5,
	MinRebirthsToTrade = 0,
	LogStore = "TradeLog_v1", -- every completed trade is written here (and printed to the server output)
}
