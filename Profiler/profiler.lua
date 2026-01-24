--[[
    Core Profiler Module - Simplified Microprofiler
    Coordinates the microprofiler and UI modules
    Used by: Main.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: Main ]]
local config = require("Profiler.config")
local MicroProfiler = require("Profiler.microprofiler") --[[ Imported by: profiler ]]
local UITop = require("Profiler.ui_top") --[[ Imported by: profiler ]]
local UIBody = require("Profiler.ui_body_simple") --[[ Imported by: profiler ]]

-- Module declaration
local ProfilerCore = {}

-- Local constants / utilities -------- (Lua 5.4 compatible)
local TOP_BAR_HEIGHT = 60 -- Increased to match ui_top.lua

-- Local variables
local isVisible = config.visible or false
local isInitialized = false

-- Private helpers --------------------

local function initialize()
	if isInitialized then
		return
	end

	-- Initialize UI modules
	UITop.Initialize()
	UIBody.Initialize()

	isInitialized = true
end

local function shutdown()
	if not isInitialized and not isVisible then
		-- Even if we never initialized, make sure runtime data is cleared
		MicroProfiler.Disable()
		MicroProfiler.Reset()
		UIBody.SetVisible(false)
		Shared.ProfilerEnabled = false
		return
	end

	MicroProfiler.Disable()
	MicroProfiler.Reset()
	UIBody.SetVisible(false)
	Shared.ProfilerEnabled = false
	isVisible = false
	isInitialized = false
end

function ProfilerCore.Init()
	initialize()
	return ProfilerCore
end

function ProfilerCore.Shutdown()
	shutdown()
	package.loaded["Profiler"] = nil
	package.loaded["Profiler.profiler"] = nil
	package.loaded["Profiler.microprofiler"] = nil
	package.loaded["Profiler.ui_top"] = nil
	package.loaded["Profiler.ui_body_simple"] = nil
	package.loaded["Profiler.ui_body"] = nil
	package.loaded["Profiler.Shared"] = nil
	package.loaded["Profiler.config"] = nil
	package.loaded["Profiler.timing"] = nil
	package.loaded["Profiler.ui_warning"] = nil
end

-- Public API -------------------------

function ProfilerCore.SetVisible(visible)
	if not isInitialized then
		initialize()
	end

	isVisible = visible
	Shared.ProfilerEnabled = visible

	if visible then
		-- Set RecordingStartTime when profiling starts for fixed coordinate system
		if not Shared.RecordingStartTime then
			Shared.RecordingStartTime = os.clock()
			print(string.format("📍 Profiler: RecordingStartTime set to %.6f", Shared.RecordingStartTime))
		end
		MicroProfiler.Enable()
	else
		MicroProfiler.Disable()
		-- Reset RecordingStartTime when profiling stops so next session starts fresh
		Shared.RecordingStartTime = nil
	end

	UIBody.SetVisible(visible)
end

function ProfilerCore.ToggleVisibility()
	ProfilerCore.SetVisible(not isVisible)
	return isVisible
end

function ProfilerCore.IsVisible()
	return isVisible
end

-- Manual profiling API (for custom work items)
function ProfilerCore.Begin(name, category)
	if not isVisible then
		return
	end
	-- Check if paused via UITop module
	if not isInitialized then
		initialize()
	end
	if UITop.IsPaused() then
		return -- Don't start manual profiling when paused
	end
	MicroProfiler.BeginCustomWork(name, category)
end

function ProfilerCore.End(name)
	if not isVisible then
		return
	end
	-- Check if paused via UITop module
	if not isInitialized then
		initialize()
	end
	if UITop.IsPaused() then
		return -- Don't end manual profiling when paused
	end
	-- If no name supplied, end the most‐recent Begin()
	if not name or name == "" then
		name = nil -- pop last
	end
	MicroProfiler.EndCustomWork(name)
end

-- Legacy API support (keeping for compatibility)
function ProfilerCore.StartSystem(name)
	ProfilerCore.Begin("System: " .. name)
end

function ProfilerCore.EndSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.End(scopeName)
end

function ProfilerCore.StartComponent(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.EndComponent(name)
	ProfilerCore.End(name)
end

-- Simplified system API
function ProfilerCore.BeginSystem(name)
	ProfilerCore.Begin("System: " .. name)
end

function ProfilerCore.StopSystem(name)
	local scopeName = "System: " .. name
	ProfilerCore.End(scopeName)
end

-- New minimalist API
function ProfilerCore.Start(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.Finish(name)
	ProfilerCore.End(name)
end

-- Pause/Resume controls
function ProfilerCore.TogglePause()
	if not isInitialized then
		initialize()
	end

	local wasPaused = UITop.IsPaused()
	UITop.SetPaused(not wasPaused)
	return not wasPaused
end

function ProfilerCore.IsPaused()
	if not isInitialized then
		return false
	end
	return UITop.IsPaused()
end

-- Body visibility controls
function ProfilerCore.ToggleBody()
	if not isInitialized then
		initialize()
	end
	return UIBody.ToggleVisible()
end

function ProfilerCore.SetBodyVisible(visible)
	if not isInitialized then
		initialize()
	end
	UIBody.SetVisible(visible)
end

function ProfilerCore.IsBodyVisible()
	if not isInitialized then
		return false
	end
	return UIBody.IsVisible()
end

-- Config helpers (simplified)
function ProfilerCore.SetSortMode(mode)
	config.sortMode = mode
end

function ProfilerCore.SetWindowSize(size)
	config.windowSize = math.max(1, math.min(300, size))
end

function ProfilerCore.SetSmoothingSpeed(speed)
	config.smoothingSpeed = math.max(1, math.min(50, speed))
end

function ProfilerCore.SetSmoothingDecay(decay)
	config.smoothingDecay = math.max(1, math.min(50, decay))
end

function ProfilerCore.SetTextUpdateInterval(interval)
	config.textUpdateInterval = math.max(1, interval)
end

function ProfilerCore.SetSystemMemoryMode(mode)
	config.systemMemoryMode = mode
end

function ProfilerCore.SetOverheadCompensation(enabled)
	-- Placeholder for future implementation
end

-- Reset profiler state
function ProfilerCore.Reset()
	MicroProfiler.Reset()
	if isInitialized then
		UITop.Initialize()
		UIBody.Initialize()
	end
end

-- Main draw function
function ProfilerCore.Draw()
	if not isVisible then
		return
	end
	if not isInitialized then
		initialize()
	end

	-- Update frame counter
	Shared.CurrentFrame = Shared.CurrentFrame + 1

	-- Check for body toggle request from UI
	if Shared.BodyToggleRequested then
		ProfilerCore.ToggleBody()
		Shared.BodyToggleRequested = false
	end

	-- Update and draw top bar
	UITop.Update()
	UITop.Draw()

	-- Draw body whenever there's data (simple system)
	if UIBody.IsVisible() then
		local profilerData = MicroProfiler.GetProfilerData()
		UIBody.Draw(profilerData, TOP_BAR_HEIGHT)
	end

	-- Store last draw time
	Shared.LastDrawTime = os.clock()
end

-- Get profiler data for external use
function ProfilerCore.GetMainTimeline()
	return MicroProfiler.GetMainTimeline()
end

function ProfilerCore.GetCustomThreads()
	return MicroProfiler.GetCustomThreads()
end

function ProfilerCore.GetCallStack()
	return MicroProfiler.GetCallStack()
end

function ProfilerCore.GetProfilerData()
	return MicroProfiler.GetProfilerData()
end

function ProfilerCore.GetStats()
	return MicroProfiler.GetStats()
end

-- Debug functions
function ProfilerCore.PrintStats()
	MicroProfiler.PrintStats()
end

function ProfilerCore.PrintTimeline(maxDepth)
	MicroProfiler.PrintTimeline(maxDepth)
end

-- Camera controls for body
function ProfilerCore.ResetCamera()
	if not isInitialized then
		initialize()
	end
	UIBody.ResetCamera()
end

function ProfilerCore.SetZoom(zoom)
	if not isInitialized then
		initialize()
	end
	UIBody.SetZoom(zoom)
end

function ProfilerCore.GetZoom()
	if not isInitialized then
		return 1.0
	end
	return UIBody.GetZoom()
end

-- Measurement mode (tick vs frame)
function ProfilerCore.SetMeasurementMode(mode)
	if mode == "tick" or mode == "frame" then
		Shared.MeasurementMode = mode
		-- RecordingStartTime is now set when profiling starts, not when mode changes
	end
end

function ProfilerCore.GetMeasurementMode()
	return Shared.MeasurementMode or "frame"
end

-- Initialize if visible by default
if isVisible then
	initialize()
	MicroProfiler.Enable()
end

return ProfilerCore
