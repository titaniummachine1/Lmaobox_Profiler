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

-- Check if an older version of the profiler is already loaded and unload it
local previouslyLoaded = package.loaded["Profiler"]
if previouslyLoaded and previouslyLoaded.Unload then
	previouslyLoaded.Unload()
end

-- Global shared table (from globals.lua) – *not* _G
local G = require("Profiler.globals")

-- Flags stored in G to track profiler state
G.ProfilerLoaded = false
G.ProfilerCallbacksRegistered = false
G.ProfilerEnabled = false

-- Import core module (does **not** register callbacks on its own)
local ProfilerCore = require("Profiler.profiler")

-- Public API table
local Profiler = {}

-- Re-export core functions
Profiler.SetVisible = ProfilerCore.SetVisible
Profiler.StartSystem = ProfilerCore.StartSystem
Profiler.StartComponent = ProfilerCore.StartComponent
Profiler.EndComponent = ProfilerCore.EndComponent
Profiler.EndSystem = ProfilerCore.EndSystem
Profiler.Draw = ProfilerCore.Draw

-- Config helpers
Profiler.SetSortMode = ProfilerCore.SetSortMode
Profiler.SetWindowSize = ProfilerCore.SetWindowSize
Profiler.SetSmoothingSpeed = ProfilerCore.SetSmoothingSpeed
Profiler.SetSmoothingDecay = ProfilerCore.SetSmoothingDecay
Profiler.Reset = ProfilerCore.Reset

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

-- Remove safeRegisterCallback function and use direct callbacks.Register
-- Automatic Draw callback (retained-mode) ------------------------------------
-------------------------------------------------------------------------------

local DRAW_CB_ID = "profiler_auto_draw"
if not G.ProfilerCallbacksRegistered and callbacks and callbacks.Register then
	if callbacks.Unregister then
		callbacks.Unregister("Draw", DRAW_CB_ID)
	end

	callbacks.Register("Draw", DRAW_CB_ID, function()
		-- Draw only when visible to avoid wasting time
		Profiler.Draw()
	end)

	G.ProfilerCallbacksRegistered = true
end

-- Cleanup helper -------------------------------------------------------------
function Profiler.Unload()
	-- Unregister draw callback
	if callbacks and callbacks.Unregister then
		callbacks.Unregister("Draw", DRAW_CB_ID)
	end
	G.ProfilerCallbacksRegistered = false

	-- Reset internal state so a fresh load starts clean
	Profiler.Reset()

	-- Remove from package cache
	package.loaded["Profiler"] = nil
	package.loaded["Profiler.profiler"] = nil
	package.loaded["Profiler.globals"] = nil
	package.loaded["Profiler.config"] = nil
	package.loaded["Profiler.Main"] = nil

	print("✅ Profiler unloaded. Ready for reload.")
end

-- Mark library as loaded
G.ProfilerLoaded = true

-- Return shared instance -----------------------------------------------------
return Profiler
