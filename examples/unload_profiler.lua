--[[
    Profiler Unloader - Clean up before reloading
    
    Run this before loading an updated version of the Profiler:
    lua_load unload_profiler.lua
    
    Then load the new version:
    lua_load Profiler.lua
]]

print("🧹 Unloading Profiler...")

-- Clear all package cache entries for Profiler
local profilerModules = {
	"Profiler",
	"Profiler.profiler",
	"Profiler.globals",
	"Profiler.config",
	"Profiler.Main",
}

for _, moduleName in ipairs(profilerModules) do
	if package.loaded[moduleName] then
		package.loaded[moduleName] = nil
		print("   📦 Cleared: " .. moduleName)
	end
end

-- Try to get existing profiler and clean it up
local success, existingProfiler = pcall(require, "Profiler")
if success and existingProfiler and existingProfiler.Unload then
	existingProfiler.Unload()
else
	print("   ⚠️ No existing Profiler found or no Unload function")
end

-- Clear any global state (using custom G module, not _G)
local success, G = pcall(require, "Profiler.globals")
if success and G then
	G.ProfilerLoaded = false
	G.ProfilerCallbacksRegistered = false
	G.ProfilerEnabled = false
	print("   🌐 Cleared global state")
end

-- Force garbage collection to clean up memory
collectgarbage("collect")

print("✅ Profiler cleanup complete! Safe to load updated version.")
print("   Next: lua_load Profiler.lua")

--[[
    Usage:
    
    1. Run this unloader:
       lua_load unload_profiler.lua
       
    2. Load updated profiler:
       lua_load Profiler.lua
       
    3. Or load your example:
       lua_load example.lua
]]
