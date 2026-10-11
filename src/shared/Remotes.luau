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
	"Sfx", -- (soundName) plays a SoundConfig effect
	"Fx", -- (kind, position?) visual effect: "Confetti", "Upgrade", "Rebirth", "Coins"
	"PetHatched", -- (petType, eggId)
	"TradeInvite", -- (fromUserId, fromName)
	"TradeState", -- (state table)

	-- client -> server
	"RequestRebirth", -- ()
	"HireWorker", -- (workerId)
	"DismissWorker", -- (workerId)
	"RequestPurchase", -- (kind: "Pass" | "Product", key)
	"ArenaAction", -- (action: "Leave" | "Deploy" | "Recall")
	"SetSetting", -- (key, value) player preferences from DataConfig.Template.Settings
	"ClaimDaily", -- ()
	"ClaimQuest", -- (index)
	"HatchEgg", -- (eggId)
	"PetAction", -- (action: "Equip" | "Unequip" | "Delete", petId)
	"VisitPlot", -- (plotId)
	"TradeRequest", -- (targetUserId)
	"TradeRespond", -- (fromUserId, accept)
	"TradeOffer", -- (robots, prototypes)
	"TradeReady", -- (ready)
	"TradeCancel", -- ()
	"BuyWeapon", -- (weaponId)
	"SetPvP", -- (on)
	"FireWeapon", -- (weaponId, targetPosition) ranged weapons
}
