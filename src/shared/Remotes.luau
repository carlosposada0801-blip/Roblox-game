--[[
	Remotes
	Names of every RemoteEvent. The server creates them in
	ReplicatedStorage.Remotes; the client waits for them. Every
	client -> server remote is rate limited on the server (see Net).
]]

return {
	-- server -> client
	"Notify", -- (text, kind)
	"CashPopup", -- (amount)

	-- client -> server
	"RequestRebirth", -- ()
	"HireWorker", -- (workerId)
	"DismissWorker", -- (workerId)
	"RequestPurchase", -- (kind: "Pass" | "Product", key)
	"ArenaAction", -- (action: "Leave" | "Deploy" | "Recall")
}
