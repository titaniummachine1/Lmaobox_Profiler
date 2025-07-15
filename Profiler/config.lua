--[[
    Profiler Configuration File
    Modify these values to customize profiler behavior
]]

return {
	-- Display settings
	visible = true, -- Start with profiler visible or hidden
	windowSize = 60, -- Number of frames to average over (1-300)
	sortMode = "size", -- "size" (biggest first), "static" (measurement order), "reverse" (smallest first)
	systemHeight = 48, -- Height of each system bar in pixels
	fontSize = 12, -- Font size for text
	maxSystems = 20, -- Maximum number of systems to display
	textPadding = 6, -- Padding around text in components
	smoothingSpeed = 2.5, -- Percentage of width to move per frame towards target (1-50%, higher = less smooth but more responsive)
	smoothingDecay = 1.5, -- Percentage of width to move per frame when decaying (1-50%, lower = slower decay, peaks stay longer)
	textUpdateInterval = 20, -- Update text every N frames (20 frames = 333ms at 60fps, 3 times per second max)
	systemMemoryMode = "system", -- "system" (actual system memory usage) or "components" (sum of component memory)
}
