--[[
	ChatController
	Adds [👑 VIP], [Crew] and title tags in front of chat messages, using the
	sender's attributes (Pass_VIPFloor, CrewName, Title). Works with TextChatService.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatController = {}

function ChatController:Start()
	TextChatService.OnIncomingMessage = function(message)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender then
			local prefix = ""
			if sender:GetAttribute("Pass_VIPFloor") then
				prefix ..= '<font color="#FFC832">[👑 VIP]</font> '
			end
			local crew = sender:GetAttribute("CrewName")
			if crew and crew ~= "" then
				prefix ..= ('<font color="#4FA3FF">[%s]</font> '):format(crew)
			end
			local title = sender:GetAttribute("Title")
			if title and title ~= "" then
				prefix ..= ('<font color="#FFD25A">[%s]</font> '):format(title)
			end
			if prefix ~= "" then
				properties.PrefixText = prefix .. message.PrefixText
			end
		end
		return properties
	end
end

return ChatController
