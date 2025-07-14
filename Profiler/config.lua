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
	smoothingSpeed = 5.0, -- How fast bars scale up to peaks (higher = faster response to spikes, 0.1-20.0)
	smoothingDecay = 1.0, -- How fast bars scale down from peaks (lower = slower decay, shows peaks longer, 0.1-20.0)
	textUpdateInterval = 15, -- Update text every N frames (15 frames = 250ms at 60fps, 4 times per second max)
	systemMemoryMode = "system", -- "system" (actual system memory usage) or "components" (sum of component memory)
}
