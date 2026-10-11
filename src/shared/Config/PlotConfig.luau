--[[
	PlotConfig
	Layout and look of the tycoon plots. PlotService generates the plots at
	runtime from this table, so you can change the count or sizes here without
	building anything by hand in Studio.

	Plot local space (used by every later config that positions things on a plot):
	  origin = center of the plot floor (top surface)
	  +Z     = entrance side, facing the central aisle
	  -Z     = back of the factory
]]

local PlotConfig = {}

PlotConfig.PlotCount = 6
PlotConfig.Columns = 3 -- plots per row; rows alternate sides of the aisle

PlotConfig.PlotSize = Vector3.new(100, 1, 100) -- X = width, Y = floor thickness, Z = depth
PlotConfig.PlotGap = 24 -- studs between neighbouring plots in one row
PlotConfig.AisleWidth = 60 -- walkway between the two rows (the lobby spawn sits here)
PlotConfig.Origin = Vector3.new(0, 0, 0) -- ground height and center of the whole layout

-- Lobby spawn (world position). The middle of the aisle is the speedy walkway.
PlotConfig.LobbySpawn = Vector3.new(-40, 0.5, 19)

-- Where the owner appears, relative to the plot center
PlotConfig.SpawnOffset = CFrame.new(0, 4, 42)

PlotConfig.BaseColor = Color3.fromRGB(62, 66, 74)
PlotConfig.BaseMaterial = Enum.Material.DiamondPlate

-- One accent color per plot (border + sign). Extra plots reuse colors.
PlotConfig.AccentColors = {
	Color3.fromRGB(255, 170, 0),
	Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(85, 255, 127),
	Color3.fromRGB(255, 85, 127),
	Color3.fromRGB(170, 85, 255),
	Color3.fromRGB(255, 255, 127),
}

PlotConfig.UnclaimedText = "Unclaimed Factory"
PlotConfig.ClaimedTextFormat = "%s's Robot Factory"

return PlotConfig
