--[[
    Profiler Library - Main Entry Point
    Author: titaniummachine1
    
    A lightweight performance profiler for Lua applications
    
    Usage:
        local Profiler = require("Profiler")
        
        -- Control visibility
        Profiler.SetVisible(true)
        
        -- Measure performance
        Profiler.StartSystem("system_name")
            Profiler.StartComponent("component_name")
            -- ... your code ...
            Profiler.EndComponent("component_name")
        Profiler.EndSystem("system_name")
        
        -- In draw callback
        Profiler.Draw()
]]

-- Global shared table (from Shared.lua) – retained mode
local Shared = require("Profiler.Shared")

-- RELOAD DETECTION: Check if profiler is already loaded
if Shared.ProfilerInstance and Shared.ProfilerLoaded then
	print("🔄 Microprofiler already loaded - performing full reload...")

	-- Unload existing instance completely
	if Shared.ProfilerInstance.Unload then
		Shared.ProfilerInstance.Unload()
	end

	-- Force clear all package cache (improved pattern)
	local packagesToClear = {
		"Profiler",
		"Profiler.profiler",
		"Profiler.microprofiler",
		"Profiler.ui_top",
		"Profiler.ui_body",
		"Profiler.Shared",
		"Profiler.config",
		"Profiler.Main",
		"Profiler.timing",
		"Profiler.ui_warning",
	}

	for _, pkg in ipairs(packagesToClear) do
		if package.loaded[pkg] then
			package.loaded[pkg] = nil
		end
	end

	-- Clear global state
	Shared.ProfilerInstance = nil
	Shared.ProfilerLoaded = false

	-- Re-require Shared to get fresh state
	Shared = require("Profiler.Shared")

	print("📦 All packages cleared - loading fresh profiler...")
end

-- Check if an older version of the profiler is already loaded and unload it
local previouslyLoaded = package.loaded["Profiler"]
if previouslyLoaded and previouslyLoaded.Unload then
	previouslyLoaded.Unload()
end

-- Initialize profiler state flags (now in retained globals)
ProfilerLoaded = false -- Global variable (not local)
ProfilerCallbacksRegistered = false -- Global variable
ProfilerEnabled = false -- Global variable

-- Import core module (does **not** register callbacks on its own)
local ProfilerCore = require("Profiler.profiler")
ProfilerCore.Init()

-- Public API table
local Profiler = {}

-- Re-export core functions (original API)
Profiler.SetVisible = ProfilerCore.SetVisible
Profiler.StartSystem = ProfilerCore.StartSystem
Profiler.StartComponent = ProfilerCore.StartComponent
Profiler.EndComponent = ProfilerCore.EndComponent
Profiler.EndSystem = ProfilerCore.EndSystem
Profiler.Draw = ProfilerCore.Draw

-- New minimalist API for nested scopes
Profiler.Start = ProfilerCore.Start
Profiler.Finish = ProfilerCore.Finish
Profiler.TogglePause = ProfilerCore.TogglePause
Profiler.IsPaused = ProfilerCore.IsPaused
Profiler.ToggleVisibility = ProfilerCore.ToggleVisibility

-- Simplified API - explicit systems, Begin for components
Profiler.BeginSystem = ProfilerCore.BeginSystem
Profiler.EndSystem = ProfilerCore.StopSystem -- No parameters needed
Profiler.Begin = ProfilerCore.Begin -- Always for components
Profiler.End = ProfilerCore.End -- Always for components

-- Config helpers
Profiler.SetSortMode = ProfilerCore.SetSortMode
Profiler.SetWindowSize = ProfilerCore.SetWindowSize
Profiler.SetSmoothingSpeed = ProfilerCore.SetSmoothingSpeed
Profiler.SetSmoothingDecay = ProfilerCore.SetSmoothingDecay
Profiler.SetTextUpdateInterval = ProfilerCore.SetTextUpdateInterval
Profiler.SetSystemMemoryMode = ProfilerCore.SetSystemMemoryMode
Profiler.SetOverheadCompensation = ProfilerCore.SetOverheadCompensation
Profiler.SetAutoHookEnabled = ProfilerCore.SetAutoHookEnabled
Profiler.IsAutoHookEnabled = ProfilerCore.IsAutoHookEnabled
Profiler.SetMeasurementMode = ProfilerCore.SetMeasurementMode
Profiler.GetMeasurementMode = ProfilerCore.GetMeasurementMode
Profiler.Init = ProfilerCore.Init
Profiler.Shutdown = ProfilerCore.Shutdown
Profiler.Reset = ProfilerCore.Reset

-- Metadata constants (Lua 5.4 compatible)
Profiler.VERSION = "1.0.0"
Profiler.AUTHOR = "titaniummachine1"

-- Convenience helpers --------------------------------------------------------
function Profiler.Enable()
	Profiler.SetVisible(true)
	return Profiler
end

function Profiler.Disable()
	Profiler.SetVisible(false)
	return Profiler
end

function Profiler.Setup(cfg)
	cfg = cfg or {}
	if cfg.visible ~= nil then
		Profiler.SetVisible(cfg.visible)
	end
	if cfg.sortMode then
		Profiler.SetSortMode(cfg.sortMode)
	end
	if cfg.windowSize then
		Profiler.SetWindowSize(cfg.windowSize)
	end
	if cfg.smoothingSpeed then
		Profiler.SetSmoothingSpeed(cfg.smoothingSpeed)
	end
	if cfg.smoothingDecay then
		Profiler.SetSmoothingDecay(cfg.smoothingDecay)
	end
	if cfg.textUpdateInterval then
		Profiler.SetTextUpdateInterval(cfg.textUpdateInterval)
	end
	if cfg.systemMemoryMode then
		Profiler.SetSystemMemoryMode(cfg.systemMemoryMode)
	end
	if cfg.compensateOverhead ~= nil then
		Profiler.SetOverheadCompensation(cfg.compensateOverhead)
	end
	return Profiler
end

-- Time helper for quick instrumentation
function Profiler.Time(systemName, componentName, func)
	if not func then
		-- Called as (componentName, func)
		func = componentName
		componentName = systemName
		systemName = "default"
	end
	Profiler.StartSystem(systemName)
	Profiler.StartComponent(componentName)
	local result = func()
	Profiler.EndComponent(componentName)
	Profiler.EndSystem(systemName)
	return result
end

-- Manual reload helper for development
function Profiler.Reload()
	print("🔄 Manual reload requested...")
	Profiler.Unload()
	print("🚀 Run 'lua_load example.lua' again to get fresh profiler!")
end

-- Cleanup helper (enhanced for complete reloading) -------------------------
function Profiler.Unload()
	print("🧹 Unloading Microprofiler...")

	Profiler.Shutdown()
	ProfilerCallbacksRegistered = false

	-- Reset internal state so a fresh load starts clean
	print("   ✓ Internal state reset")

	-- Clear global instance
	Shared.ProfilerInstance = nil
	Shared.ProfilerLoaded = false
	ProfilerLoaded = false
	print("   ✓ Global state cleared")

	-- Remove ALL profiler packages from cache (improved pattern)
	local packages = {
		"Profiler",
		"Profiler.profiler",
		"Profiler.microprofiler",
		"Profiler.ui_top",
		"Profiler.ui_body",
		"Profiler.Shared",
		"Profiler.config",
		"Profiler.Main",
		"Profiler.timing",
		"Profiler.ui_warning",
	}

	for _, pkg in ipairs(packages) do
		if package.loaded[pkg] then
			package.loaded[pkg] = nil
			print(string.format("   ✓ Unloaded package: %s", pkg))
		end
	end
	print("   ✓ Package cache cleared")

	print("✅ Microprofiler completely unloaded. Ready for fresh reload.")
end

-- Mark library as loaded (global retained mode)
ProfilerLoaded = true
Shared.ProfilerLoaded = true
Shared.ProfilerInstance = Profiler

print("🚀 Microprofiler singleton initialized!")

-- Return shared instance (store in global for retention) --------------------
return Profiler
