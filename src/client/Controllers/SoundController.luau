--[[
	SoundController
	Plays sound effects the server asks for (Sfx remote): purchases,
	denied purchases, cash collected, rebirths. Menu clicks are played
	directly by UIKit buttons.
]]

local Net = require(script.Parent.Parent.Net)
local Sfx = require(script.Parent.Parent.Sfx)

local SoundController = {}

function SoundController:Start()
	Net.On("Sfx", function(name)
		if type(name) == "string" then
			Sfx.play(name)
		end
	end)
end

return SoundController
