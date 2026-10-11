--[[
	EventController
	Banner at the top of the screen while a factory event is running,
	with a countdown. Reads workspace attributes Event / EventEndsAt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EventConfig"))
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Theme = UIKit.Theme

local EventController = {}

function EventController:Start()
	local banner = UIKit.create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(460, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = UIKit.root(),
	}, { UIKit.corner(14) })
	local stroke = UIKit.stroke(Theme.Accent, 3)
	stroke.Parent = banner
	local gradient = UIKit.gradient(Theme.Accent, Theme.Background, 0)
	gradient.Parent = banner

	local title = UIKit.label({ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -90, 0, 28), Font = Theme.Title, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.4, MaxTextSize = 24, Parent = banner })
	local description = UIKit.label({ Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -90, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = banner })
	local timer = UIKit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(70, 40), Font = Theme.Title, MaxTextSize = 30, Parent = banner })

	local function update()
		local id = workspace:GetAttribute("Event") or ""
		local event = EventConfig.Events[id]
		if not event then
			banner.Visible = false
			return
		end
		title.Text = event.DisplayName
		description.Text = event.Description
		stroke.Color = event.Color
		gradient.Color = ColorSequence.new(event.Color, Theme.Background)
		banner.Visible = true
		local scale = banner:FindFirstChildOfClass("UIScale") or UIKit.create("UIScale", { Parent = banner })
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	workspace:GetAttributeChangedSignal("Event"):Connect(update)
	update()

	RunService.Heartbeat:Connect(function()
		if banner.Visible then
			local remaining = math.max(0, (workspace:GetAttribute("EventEndsAt") or 0) - workspace:GetServerTimeNow())
			timer.Text = ("%ds"):format(math.ceil(remaining))
		end
	end)
end

return EventController
