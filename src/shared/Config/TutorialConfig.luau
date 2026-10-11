--[[
	TutorialConfig
	First-time player walkthrough. A card at the bottom of the screen shows
	the current step and a bouncing arrow points at what to do:
	  Owns = "<itemId>"  step on that buy button (the arrow points at it)
	  Collect = true     step on the cash pad
	  Rebirth = true     waits until a rebirth is affordable, then points at
	                     the REBIRTH menu button; done after the first rebirth
	Progress is saved (data.TutorialStep), so it continues where it left off
	and never repeats. Players can Skip at any time.
	Reward is given once, after the RewardAfterStep step (server-checked).
]]

return {
	Reward = { Cash = 250 },
	RewardAfterStep = 6,
	Steps = {
		{ Text = "Welcome, boss! Step on the glowing CONVEYOR BELT button to start your factory.", Owns = "MainConveyor" },
		{ Text = "Nice! Now step on the COLLECTOR button. It turns robots into cash.", Owns = "Collector" },
		{ Text = "Buy your first SCRAP DROPPER. It drops scrap onto the belt.", Owns = "Dropper1" },
		{ Text = "Save up $75 and buy a second dropper for double the scrap!", Owns = "Dropper2" },
		{ Text = "Buy the FACTORY FLOOR to make your factory look legit.", Owns = "FactoryFloor" },
		{ Text = "Your cash waits on the glowing CASH PAD. Walk onto it to collect!", Collect = true },
		{ Text = "You can afford a REBIRTH! Open Rebirth for a permanent cash boost.", Rebirth = true },
	},
}
