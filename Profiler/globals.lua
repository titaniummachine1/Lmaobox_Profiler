--[[
    Globals Module - Shared Runtime Data (Retained Mode)
    Used by: Main.lua, profiler.lua
    
    This module provides GLOBAL retained state to prevent multiple instances
]]

-- Module declaration
local G = {
	-- Profiler shared data
	ProfilerEnabled = false,
	CurrentFrame = 0,
	LastDrawTime = 0,
	BodyToggleRequested = false,

	-- Instance control
	ProfilerInstance = nil,
	ProfilerLoaded = false,

	-- Debug settings
	DEBUG = false,
}

-- Return the module
return G
