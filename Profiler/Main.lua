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

local G = require("Profiler.globals")

-- Import core profiler module
local ProfilerCore = require("Profiler.profiler")

-- Create the main Profiler API
local Profiler = {}

-- Core profiler functions
Profiler.SetVisible = ProfilerCore.SetVisible
Profiler.StartSystem = ProfilerCore.StartSystem
Profiler.StartComponent = ProfilerCore.StartComponent
Profiler.EndComponent = ProfilerCore.EndComponent
Profiler.EndSystem = ProfilerCore.EndSystem
Profiler.Draw = ProfilerCore.Draw

-- Configuration functions
Profiler.SetSortMode = ProfilerCore.SetSortMode
Profiler.SetWindowSize = ProfilerCore.SetWindowSize
Profiler.Reset = ProfilerCore.Reset

-- Library information
Profiler.VERSION = "1.0.0"
Profiler.AUTHOR = "titaniummachine1"

-- Convenience function to enable profiler with default settings
function Profiler.Enable()
	Profiler.SetVisible(true)
	return Profiler
end

-- Convenience function to disable profiler
function Profiler.Disable()
	Profiler.SetVisible(false)
	return Profiler
end

-- Quick setup function for common use cases
function Profiler.Setup(config)
	config = config or {}

	if config.visible ~= nil then
		Profiler.SetVisible(config.visible)
	end

	if config.sortMode then
		Profiler.SetSortMode(config.sortMode)
	end

	if config.windowSize then
		Profiler.SetWindowSize(config.windowSize)
	end

	return Profiler
end

-- Helper function for timing code blocks
function Profiler.Time(systemName, componentName, func)
	if not func then
		-- If only 2 parameters, treat as (componentName, func)
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

-- Cleanup function for proper reloading
function Profiler.Unload()
	-- Clear package cache for clean reload
	package.loaded["Profiler"] = nil
	package.loaded["Profiler.profiler"] = nil
	package.loaded["Profiler.globals"] = nil
	package.loaded["Profiler.config"] = nil
	package.loaded["Profiler.Main"] = nil

	-- Reset profiler state
	Profiler.Reset()

	print("✅ Profiler unloaded. Safe to reload with updated version.")
end

-- Auto-cleanup any existing callbacks when reloading
if G.ProfilerCallbacksRegistered then
	print("🔄 Cleaning up existing Profiler callbacks...")
	-- Note: Specific callback cleanup would happen in user scripts
	G.ProfilerCallbacksRegistered = false
end

-- Mark that profiler is loaded
G.ProfilerLoaded = true

-- Export the profiler API
return Profiler
