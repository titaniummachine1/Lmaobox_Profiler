--[[
    Core Profiler Module - Simplified Microprofiler
    Coordinates the microprofiler and UI modules
    Used by: Main.lua
]]

-- Imports
local G = require("Profiler.globals") --[[ Imported by: Main ]]
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

-- Public API -------------------------

function ProfilerCore.SetVisible(visible)
	if not isInitialized then
		initialize()
	end

	isVisible = visible
	G.ProfilerEnabled = visible

	if visible then
		MicroProfiler.Enable()
	else
		MicroProfiler.Disable()
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

-- Manual profiling API (for custom threads)
function ProfilerCore.Begin(name)
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
	MicroProfiler.BeginCustomThread(name)
end

function ProfilerCore.End()
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
	MicroProfiler.EndCustomThread()
end

-- Legacy API support (keeping for compatibility)
function ProfilerCore.StartSystem(name)
	ProfilerCore.Begin("System: " .. name)
end

function ProfilerCore.EndSystem(name)
	ProfilerCore.End()
end

function ProfilerCore.StartComponent(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.EndComponent(name)
	ProfilerCore.End()
end

-- Simplified system API
function ProfilerCore.BeginSystem(name)
	ProfilerCore.Begin("System: " .. name)
end

function ProfilerCore.StopSystem()
	ProfilerCore.End()
end

-- New minimalist API
function ProfilerCore.Start(name)
	ProfilerCore.Begin(name)
end

function ProfilerCore.Finish()
	ProfilerCore.End()
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
	G.CurrentFrame = G.CurrentFrame + 1

	-- Check for body toggle request from UI
	if G.BodyToggleRequested then
		ProfilerCore.ToggleBody()
		G.BodyToggleRequested = false
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
	G.LastDrawTime = ((_G and _G.globals) and _G.globals.RealTime and _G.globals.RealTime()) or 0
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

-- Initialize if visible by default
if isVisible then
	initialize()
	MicroProfiler.Enable()
end

return ProfilerCore
