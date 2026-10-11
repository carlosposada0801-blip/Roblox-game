--[[
	CodesPanel
	Type a promo code and press Redeem. The server checks it (CodeService)
	and answers with CodeResult(ok, message), shown under the box.
]]

local UIKit = require(script.Parent.Parent.UIKit)
local Net = require(script.Parent.Parent.Parent.Net)

local Theme = UIKit.Theme

local CodesPanel = {}

function CodesPanel.build()
	local window, content = UIKit.window("🎟️ CODES", Theme.Green, Vector2.new(460, 300))

	UIKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Enter a code from our group or social media for free rewards!",
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		MaxTextSize = 17,
		Parent = content,
	})

	local box = UIKit.create("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.PanelLight,
		Font = Theme.Title,
		PlaceholderText = "TYPE CODE HERE",
		PlaceholderColor3 = Theme.SubText,
		Text = "",
		TextColor3 = Theme.Text,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = content,
	}, { UIKit.corner(10), UIKit.stroke(Theme.Green, 2), UIKit.padding(8) })

	local result = UIKit.label({
		Name = "Result",
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		MaxTextSize = 17,
		Parent = content,
	})

	local function redeem()
		if box.Text ~= "" then
			result.Text = "Checking..."
			result.TextColor3 = Theme.SubText
			Net.Fire("RedeemCode", box.Text)
		end
	end
	UIKit.button({
		Name = "Redeem",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 52),
		Color = Theme.Green,
		Text = "REDEEM",
		Parent = content,
	}, redeem)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)

	Net.On("CodeResult", function(ok, message)
		result.Text = tostring(message)
		result.TextColor3 = if ok then Theme.Green else Theme.Red
		if ok then
			box.Text = ""
		end
	end)

	return window
end

return CodesPanel
