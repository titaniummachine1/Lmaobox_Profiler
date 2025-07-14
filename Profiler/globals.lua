--[[
    Globals Module - Shared Runtime Data
    Used by: Main.lua, profiler.lua
    
    This module provides a clean namespace for shared data
    without polluting the built-in Lua global table (_G)
]]

local G = {}

-- Profiler shared data
G.ProfilerEnabled = false
G.CurrentFrame = 0
G.LastDrawTime = 0

-- Debug settings
G.DEBUG = false

return G
