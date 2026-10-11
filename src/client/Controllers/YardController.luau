--[[
	YardController
	Build mode for the Logistics Yard. YardPanel calls YardController:Select(pieceType)
	to start placing. While building:
	  * a ghost piece follows the mouse (green = OK, red = can't build there)
	  * click / tap to place, R or the ROTATE button to turn, X or DONE to stop
	  * REMOVE mode: click / tap a piece to remove it (full refund)
	Everything is checked again on the server (YardService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local YardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("YardConfig"))
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local YardController = {}

local selected -- piece type, or "Remove", or nil when not building
local rotation = 0
local ghost, ghostArrow, toolbar, toolbarLabel, removeButton
local renderConnection

local function myFloor()
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
	local yard = plot and plot:FindFirstChild("Yard")
	return yard and yard:FindFirstChild("YardFloor")
end

-- Grid cell under a screen point: intersects the camera ray with the yard floor's top plane
local function cellAt(screenPosition)
	local floor = myFloor()
	local camera = workspace.CurrentCamera
	if not (floor and camera) then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local top = floor.Position.Y + floor.Size.Y / 2
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (top - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 or t > 600 then
		return nil
	end
	local hit = ray.Origin + ray.Direction * t
	local x, y = YardConfig.CellFromOffset(floor.CFrame:PointToObjectSpace(hit))
	if not YardConfig.InBounds(x, y) then
		return nil
	end
	return x, y, floor
end

local function updateToolbar()
	if not toolbar then
		return
	end
	toolbar.Visible = selected ~= nil
	if selected == "Remove" then
		toolbarLabel.Text = "🗑️ REMOVE MODE: tap a piece to remove it (full refund)"
	elseif selected then
		local config = YardConfig.Pieces[selected]
		toolbarLabel.Text = ("%s %s  •  R / ROTATE to turn  •  click or tap the yard to build"):format(config.Icon, config.Name)
	end
	removeButton:SetAttribute("BaseColor", if selected == "Remove" then Theme.Red else Theme.Disabled)
end

local function placeAt(screenPosition)
	local x, y = cellAt(screenPosition)
	if not x then
		return
	end
	if selected == "Remove" then
		Net.Fire("YardAction", "Remove", x, y)
	elseif selected then
		Net.Fire("YardAction", "Place", x, y, selected, rotation)
	end
end

function YardController:Select(pieceType)
	selected = pieceType
	updateToolbar()
end

function YardController:Stop()
	selected = nil
	if ghost then
		ghost.Parent = nil
	end
	updateToolbar()
end

function YardController:IsBuilding(): boolean
	return selected ~= nil
end

local function rotate()
	rotation = (rotation + 1) % 4
end

function YardController:Start()
	-- Ghost preview (local only)
	ghost = Instance.new("Part")
	ghost.Name = "YardGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Material = Enum.Material.Neon
	ghost.Transparency = 0.5
	ghost.Size = Vector3.new(YardConfig.CellSize - 0.3, 0.5, YardConfig.CellSize - 0.3)
	ghostArrow = Instance.new("Part")
	ghostArrow.Name = "Arrow"
	ghostArrow.Anchored = true
	ghostArrow.CanCollide = false
	ghostArrow.CanQuery = false
	ghostArrow.CanTouch = false
	ghostArrow.Material = Enum.Material.Neon
	ghostArrow.Color = Color3.new(1, 1, 1)
	ghostArrow.Size = Vector3.new(1.6, 0.6, 0.6)
	ghostArrow.Parent = ghost

	-- Toolbar (bottom of the screen, above the jump button area on phones)
	toolbar = UIKit.card({
		Name = "YardToolbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(620, 110),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = UIKit.root(),
	}, Theme.Accent)
	toolbarLabel = UIKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 34), TextWrapped = true, Font = Theme.Title, MaxTextSize = 18, Parent = toolbar })
	local row = UIKit.create("Frame", { Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 54), BackgroundTransparency = 1, Parent = toolbar }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }),
	})
	UIKit.button({ Name = "Rotate", Size = UDim2.fromOffset(170, 54), Color = Theme.Blue, Text = "🔄 ROTATE", Parent = row }, rotate)
	removeButton = UIKit.button({ Name = "Remove", Size = UDim2.fromOffset(170, 54), Color = Theme.Disabled, Text = "🗑️ REMOVE", Parent = row }, function()
		YardController:Select(if selected == "Remove" then "Conveyor" else "Remove")
	end)
	UIKit.button({ Name = "Done", Size = UDim2.fromOffset(170, 54), Color = Theme.Green, Text = "✅ DONE", Parent = row }, function()
		YardController:Stop()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not selected or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.X then
			YardController:Stop()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			placeAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	renderConnection = RunService.RenderStepped:Connect(function()
		if not selected then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local x, y, floor = cellAt(mouse)
		if not x then
			ghost.Parent = nil
			return
		end
		local offset = YardConfig.CellOffset(x, y)
		local base = floor.CFrame * CFrame.new(offset + Vector3.new(0, floor.Size.Y / 2 + 0.3, 0)) * CFrame.Angles(0, rotation * math.pi / 2, 0)
		ghost.CFrame = base
		ghostArrow.CFrame = base * CFrame.new(0.9, 0.3, 0)
		ghostArrow.Transparency = if selected == "Remove" then 1 else 0.2
		local blocked = YardConfig.IsReserved(x, y)
		ghost.Color = if selected == "Remove" then Theme.Red elseif blocked then Theme.Red else Theme.Green
		ghost.Parent = workspace
	end)
end

return YardController
