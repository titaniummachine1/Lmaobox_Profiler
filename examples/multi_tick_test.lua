--[[
    Profile every CreateMove tick until you unload this script.
    All ticks merge into one tick.speedscope.json (timeline grows as you play).

    1. run_collector.bat
    2. lua_load multi_tick_test
    3. Play / move in-game for a few seconds
    4. Unload the script (or lua_unload) -> exports flame graph
]]

local TAG = "multi_tick_test"

local function cleanup()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Unload", TAG)
end

cleanup()

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[multi_tick_test] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript("multi_tick_test")
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local function profileTask(name, times)
	Profiler.Begin(name)
	local acc = 0
	for i = 1, times do
		acc = acc + i * i
	end
	local _ = acc
	Profiler.End(name)
end

callbacks.Register("CreateMove", TAG, function()
	Profiler.BeginTick()
	profileTask("setupBones", 40)
	profileTask("cachePlayers", 25)
	profileTask("readConfig", 15)
	Profiler.EndTick()
end)

callbacks.Register("Unload", TAG, function()
	local ok, sessionId = Profiler.EndSession()
	cleanup()
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
		print("[Profiler] Time Order view = every tick stitched on one timeline")
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end)

print("[multi_tick_test] Recording every tick — play, then unload this script to export.")
