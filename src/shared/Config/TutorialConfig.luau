--[[
	TutorialConfig
	First-time player walkthrough. Each step shows a message and is finished
	when its check passes (checked on the client from what the player owns).
	Finishing gives Reward (server-side, once).
]]

return {
	Reward = { Cash = 250 },
	Steps = {
		{ Text = "Welcome, boss! Step on the green CONVEYOR BELT button to start your factory.", Owns = "MainConveyor" },
		{ Text = "Nice! Now step on the COLLECTOR button. It turns robots into cash.", Owns = "Collector" },
		{ Text = "Buy your first SCRAP DROPPER. It drops scrap onto the belt.", Owns = "Dropper1" },
		{ Text = "Scrap is turning into cash! Walk onto the glowing CASH PAD to collect it.", Collect = true },
		{ Text = "Save up and buy the next dropper. Follow the yellow arrow!", Owns = "Dropper2" },
	},
}
