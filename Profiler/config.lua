--[[
    Profiler Configuration File
    Modify these values to customize profiler behavior
]]

return {
	-- Display settings
	visible = false, -- Start with profiler visible or hidden
	windowSize = 60, -- Number of frames to average over (1-300)
	sortMode = "size", -- "size" (biggest first), "static" (measurement order), "reverse" (smallest first)
	systemHeight = 48, -- Height of each system bar in pixels
	fontSize = 12, -- Font size for text
	maxSystems = 20, -- Maximum number of systems to display
	textPadding = 6, -- Padding around text in components
}
