--[[
	MonetizationConfig
	Game passes and developer products. All IDs are placeholders (0).

	To go live:
	  1. Creator Dashboard > your experience > Monetization > Passes / Developer Products
	  2. Create each one and paste its ID below.
	While an ID is 0, buying it in Studio simulates the purchase (so you can test),
	and in a live game the shop says it isn't available yet.
]]

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	DoubleCash = {
		Id = 0,
		DisplayName = "2x Cash",
		Description = "Double all cash from your collector, forever.",
		Icon = "💰",
		PriceText = "R$ 199",
		Order = 1,
	},
	AutoCollect = {
		Id = 0,
		DisplayName = "Auto-Collect",
		Description = "Cash goes straight to you. No need to step on the pad.",
		Icon = "🧲",
		PriceText = "R$ 99",
		Order = 2,
	},
	FasterConveyors = {
		Id = 0,
		DisplayName = "Faster Conveyors",
		Description = "Belts move 50% faster.",
		Icon = "⏩",
		PriceText = "R$ 149",
		Order = 3,
	},
	VIPFloor = {
		Id = 0,
		DisplayName = "VIP Floor",
		Description = "A golden VIP lounge with a VIP dropper that drops pre-smelted metal.",
		Icon = "👑",
		PriceText = "R$ 249",
		Order = 4,
	},
}

MonetizationConfig.DoubleCashMultiplier = 2
MonetizationConfig.FasterConveyorMultiplier = 1.5

-- Kind: "Cash" | "NextUpgrade" | "Prototype"
MonetizationConfig.Products = {
	SmallCash = {
		Id = 0,
		DisplayName = "Cash Pack",
		Description = "$5K x your rebirth multiplier",
		Icon = "💵",
		PriceText = "R$ 25",
		Kind = "Cash",
		Amount = 5000,
		Order = 1,
	},
	MediumCash = {
		Id = 0,
		DisplayName = "Cash Crate",
		Description = "$30K x your rebirth multiplier",
		Icon = "💼",
		PriceText = "R$ 99",
		Kind = "Cash",
		Amount = 30000,
		Order = 2,
	},
	LargeCash = {
		Id = 0,
		DisplayName = "Cash Vault",
		Description = "$200K x your rebirth multiplier",
		Icon = "🏦",
		PriceText = "R$ 399",
		Kind = "Cash",
		Amount = 200000,
		Order = 3,
	},
	NextUpgrade = {
		Id = 0,
		DisplayName = "Instant Upgrade",
		Description = "Instantly unlock your cheapest available item.",
		Icon = "🛠️",
		PriceText = "R$ 49",
		Kind = "NextUpgrade",
		FallbackCash = 25000, -- given instead if everything is already unlocked
		Order = 4,
	},
	Prototype = {
		Id = 0,
		DisplayName = "Prototype Robot",
		Description = "Unlock a Prototype robot to fight with in the arena.",
		Icon = "⭐",
		PriceText = "R$ 299",
		Kind = "Prototype",
		Order = 5,
	},
}

-- Cash packs are multiplied by the buyer's rebirth multiplier so they stay useful
MonetizationConfig.CashPacksScaleWithRebirths = true

-- How many processed receipt IDs to remember per player (prevents double grants)
MonetizationConfig.ReceiptHistorySize = 50

return MonetizationConfig
