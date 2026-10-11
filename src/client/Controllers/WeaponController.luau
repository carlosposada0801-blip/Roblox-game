--[[
	WeaponController
	  * Ranged weapons and rockets: when you click with one equipped, send the
	    spot you clicked to the server (FireWeapon). The server decides hits.
	  * A small ⚔️ PvP toggle in the row under the side menu.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Net = require(script.Parent.Parent.Net)
local Sfx = require(script.Parent.Parent.Sfx)

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local WeaponController = {}

local hooked = {}

local function hookTool(tool)
	if hooked[tool] or not tool:IsA("Tool") then
		return
	end
	local weaponType = tool:GetAttribute("WeaponType")
	if weaponType ~= "Ranged" and weaponType ~= "Rocket" then
		return
	end
	hooked[tool] = true
	local mouse = player:GetMouse()
	tool.Activated:Connect(function()
		Net.Fire("FireWeapon", tool:GetAttribute("WeaponId"), mouse.Hit.Position)
		Sfx.play("Click")
	end)
	tool.Destroying:Connect(function()
		hooked[tool] = nil
	end)
end

local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		task.defer(hookTool, child)
	end
	container.ChildAdded:Connect(function(child)
		task.defer(hookTool, child)
	end)
end

function WeaponController:Start()
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchContainer(child)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchContainer(backpack)
	end
	player.CharacterAdded:Connect(watchContainer)
	if player.Character then
		watchContainer(player.Character)
	end

	-- PvP toggle (third button in the row under the menu)
	local toggle
	toggle = UIKit.button({
		Name = "PvPToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 120, 0.5, 190),
		Size = UDim2.fromOffset(48, 44),
		Color = Theme.Disabled,
		Text = "⚔️",
		Parent = UIKit.root(),
	}, function()
		Net.Fire("SetPvP", not player:GetAttribute("PvP"))
	end)
	local function update()
		toggle:SetAttribute("BaseColor", if player:GetAttribute("PvP") then Theme.Red else Theme.Disabled)
	end
	player:GetAttributeChangedSignal("PvP"):Connect(update)
	update()
end

return WeaponController
