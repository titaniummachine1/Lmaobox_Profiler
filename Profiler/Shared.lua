--[[
    Shared Module - Shared Runtime Data (Retained Mode)
    Used by: Main.lua, profiler.lua, microprofiler.lua, ui_body.lua, ui_body_simple.lua, ui_top.lua
    
    This module provides shared retained state to prevent multiple instances.
    NOTE: This is NOT the external 'globals' library that provides RealTime() and FrameTime().
    That external library is safely required in each module that needs it.
    
    File renamed from globals.lua to Shared.lua to avoid naming conflicts.
]]

-- Module declaration
local Shared = {
	-- Profiler shared data
	ProfilerEnabled = false,
	CurrentFrame = 0,
	LastDrawTime = 0,
	BodyToggleRequested = false,

	-- UI State
	UITopVisible = true, -- Top bar visible by default
	UIBodyVisible = true, -- Body visible by default

	-- Measurement mode
	MeasurementMode = "frame", -- "tick" or "frame"
	RecordingStartTime = nil, -- Start time for tick counting

	-- Context separation for dual tick/frame profiling
	CurrentContext = "tick", -- "tick" or "frame"

	-- Instance control
	ProfilerInstance = nil,
	ProfilerLoaded = false,

	-- Debug settings
	DEBUG = false,

	-- Timing server status
	TimingServerAvailable = nil,
}

-- Return the module
return Shared
