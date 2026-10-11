--[[
	UIKit
	Small helpers so every screen shares one look: colors, fonts, rounded
	corners, hover effects, windows and confirmation dialogs.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Parent.Sfx)

local UIKit = {}

UIKit.Theme = {
	Background = Color3.fromRGB(14, 18, 32),
	Panel = Color3.fromRGB(24, 30, 50),
	PanelLight = Color3.fromRGB(38, 46, 72),
	Accent = Color3.fromRGB(255, 170, 0),
	Cyan = Color3.fromRGB(0, 210, 255),
	Green = Color3.fromRGB(40, 200, 110),
	Red = Color3.fromRGB(230, 60, 80),
	Blue = Color3.fromRGB(0, 140, 255),
	Purple = Color3.fromRGB(150, 70, 255),
	Pink = Color3.fromRGB(255, 80, 180),
	Disabled = Color3.fromRGB(70, 76, 92),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(160, 180, 210),
	Title = Enum.Font.Sarpanch,
	Body = Enum.Font.GothamMedium,
}
local Theme = UIKit.Theme

local root

-- The one ScreenGui every controller draws into
function UIKit.root(): ScreenGui
	if root then
		return root
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	root = Instance.new("ScreenGui")
	root.Name = "RobotFactoryUI"
	root.ResetOnSpawn = false
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.Parent = playerGui

	-- Scale everything down on small (phone) screens
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local camera = workspace.CurrentCamera
	local touch = game:GetService("UserInputService").TouchEnabled
	local function rescale()
		-- Phones are short in landscape; keep buttons big enough to tap
		local minimum = if touch then 0.62 else 0.55
		scale.Scale = math.clamp(camera.ViewportSize.Y / 850, minimum, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	return root
end

function UIKit.create(className: string, props, children)
	local instance = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end
local create = UIKit.create

-- Vertical gradient between two colors
function UIKit.gradient(top, bottom, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UIKit.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0.2,
	})
end

function UIKit.padding(pixels)
	local p = UDim.new(0, pixels)
	return create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function UIKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Body,
		TextColor3 = Theme.Text,
		TextScaled = true,
		Text = "",
	}
	for key, value in pairs(props) do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = create("TextLabel", defaults)
	create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = label })
	return label
end

local function shade(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + amount, 0, 1))
end

-- A rounded button with hover/press feedback. button:SetAttribute("Disabled", true) greys it out.
function UIKit.button(props, onClick)
	local color = props.Color or Theme.Green
	props.Color = nil

	local defaults = {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Theme.Title,
		TextColor3 = Theme.Text,
		TextScaled = true,
		Text = "",
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end

	local button = create("TextButton", defaults, {
		UIKit.corner(10),
		UIKit.stroke(shade(color, -0.35), 2),
		-- Glossy shine: lighter at the top
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 190)),
		create("UITextSizeConstraint", { MaxTextSize = 24 }),
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	button:SetAttribute("BaseColor", color)

	local function currentColor()
		return if button:GetAttribute("Disabled") then Theme.Disabled else button:GetAttribute("BaseColor")
	end
	local function tweenTo(target)
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = target }):Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(shade(currentColor(), 0.12))
	end)
	button.MouseLeave:Connect(function()
		tweenTo(currentColor())
	end)
	button:GetAttributeChangedSignal("Disabled"):Connect(function()
		button.BackgroundColor3 = currentColor()
	end)
	button:GetAttributeChangedSignal("BaseColor"):Connect(function()
		button.BackgroundColor3 = currentColor()
	end)

	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			Sfx.play("Denied")
			return
		end
		Sfx.play("Click")
		button.BackgroundColor3 = shade(currentColor(), -0.15)
		tweenTo(currentColor())
		if onClick then
			onClick()
		end
	end)

	return button
end

-- A centered window with a title bar and close button. Returns window, content.
function UIKit.window(title: string, accent: Color3, size: Vector2?)
	local windowSize = size or Vector2.new(560, 440)

	local window = create("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(windowSize.X, windowSize.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, {
		UIKit.corner(16),
		UIKit.stroke(accent, 3),
		UIKit.gradient(Color3.fromRGB(20, 26, 48), Color3.fromRGB(30, 14, 48)),
		create("UIScale", { Name = "OpenScale" }),
	})

	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = accent,
		Parent = window,
	}, { UIKit.corner(16), UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170)) })
	-- Square off the header's bottom corners
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = header,
	}, { UIKit.gradient(Color3.fromRGB(190, 190, 205), Color3.fromRGB(150, 150, 170)) })
	UIKit.label({
		Size = UDim2.new(1, -70, 1, -12),
		Position = UDim2.fromOffset(18, 6),
		Font = Theme.Title,
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 32,
		ZIndex = 2,
		Parent = header,
	})

	local close = UIKit.button({
		Name = "Close",
		Text = "X",
		Color = Theme.Red,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		ZIndex = 2,
		Parent = header,
	}, function()
		UIKit.close(window)
	end)
	close.Name = "Close"

	local content = create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 1, -80),
		BackgroundTransparency = 1,
		Parent = window,
	})

	return window, content
end

-- A dark rounded card used inside windows
function UIKit.card(props, accent)
	local defaults = { BackgroundColor3 = Theme.Panel }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return create("Frame", defaults, {
		UIKit.corner(12),
		UIKit.stroke(accent or Theme.PanelLight, 2),
		UIKit.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 215)),
	})
end

-- Progress bar; returns (frame, setProgress(fraction, text))
function UIKit.progressBar(props, color)
	local bar = create("Frame", props, { UIKit.corner(8) })
	bar.BackgroundColor3 = Theme.PanelLight
	bar.ClipsDescendants = true
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or Theme.Cyan, Parent = bar }, { UIKit.corner(8) })
	local text = UIKit.label({ Size = UDim2.fromScale(1, 1), Font = Theme.Title, MaxTextSize = 16, ZIndex = 2, Parent = bar })
	return bar, function(fraction, label)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
		text.Text = label or ""
	end
end

function UIKit.open(window)
	local scale = window:FindFirstChild("OpenScale")
	window.Visible = true
	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

function UIKit.close(window)
	window.Visible = false
end

-- Modal yes/no dialog. onConfirm runs only if the player confirms.
function UIKit.confirm(title: string, message: string, confirmText: string, onConfirm)
	local overlay = create("TextButton", {
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 50,
		Parent = UIKit.root(),
	})

	local dialog = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 240),
		BackgroundColor3 = Theme.Background,
		ZIndex = 51,
		Parent = overlay,
	}, { UIKit.corner(16), UIKit.stroke(Theme.Red, 3), UIKit.padding(18) })

	UIKit.label({ Size = UDim2.new(1, 0, 0, 40), Font = Theme.Title, Text = title, MaxTextSize = 32, ZIndex = 52, Parent = dialog })
	UIKit.label({
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 90),
		Text = message,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		MaxTextSize = 20,
		ZIndex = 52,
		Parent = dialog,
	})

	local function dismiss()
		overlay:Destroy()
	end

	UIKit.button({
		Text = "Cancel",
		Color = Theme.Disabled,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.47, 0, 0, 48),
		ZIndex = 52,
		Parent = dialog,
	}, dismiss)

	UIKit.button({
		Text = confirmText,
		Color = Theme.Red,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.47, 0, 0, 48),
		ZIndex = 52,
		Parent = dialog,
	}, function()
		dismiss()
		onConfirm()
	end)

	return overlay
end

return UIKit
