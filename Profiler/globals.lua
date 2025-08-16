--[[
    Globals Module - Shared Runtime Data (Retained Mode)
    Used by: Main.lua, profiler.lua
    
    This module provides GLOBAL retained state to prevent multiple instances
]]

-- Use actual globals for retained mode (not local)
if not _G.MICROPROFILER_GLOBALS then
	_G.MICROPROFILER_GLOBALS = {
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
end

-- Return the global instance
return _G.MICROPROFILER_GLOBALS
