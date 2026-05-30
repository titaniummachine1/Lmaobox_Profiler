--[[
    Best script for testing the Live panel (nested tree + event log).

    1. timing_collector\run\timing_collector.exe  (leave open)
    2. Browser http://127.0.0.1:9876/  →  LIVE
    3. lua_load live_demo
    4. Move / shoot in TF2 for a few seconds (do NOT unload yet)
    5. Watch sidebar tree + event log; flame graph updates each tick end
    6. Unload when done to save session
]]

local TAG = "live_demo"
local LOAD_KEY = "profiler.live_demo.v1"
local TICKS_PER_SAMPLE = 11 -- ~6 samples/sec — very visible in Live

if package.loaded[LOAD_KEY] then
	print("[live_demo] Already loaded — unload first.")
	return
end
package.loaded[LOAD_KEY] = true

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[live_demo] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript("live_demo")
Profiler.SetEnabled(true)

if not Profiler.IsCollectorAvailable() then
	print("[live_demo] Start timing_collector.exe first")
	return
end

if not Profiler.BeginSession() then
	print("[live_demo] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local sampleCount = 0
local tickCount = 0

callbacks.Register("CreateMove", TAG, function()
	tickCount = tickCount + 1
	if tickCount % TICKS_PER_SAMPLE ~= 0 then
		return
	end

	sampleCount = sampleCount + 1

	Profiler.BeginTick()
	Profiler.Begin("TickRoot")

	Profiler.Begin("aimAssist")
	for i = 1, 20 do
		local _ = i * i
	end
	Profiler.End()

	Profiler.Begin("entityLoop")
	Profiler.Begin("cachePlayers")
	for i = 1, 30 do
		local _ = i * i
	end
	Profiler.End()
	Profiler.Begin("setupBones")
	for i = 1, 25 do
		local _ = i * i
	end
	Profiler.End()
	Profiler.End() -- entityLoop

	Profiler.End() -- TickRoot
	Profiler.EndTick()

	print("[live_demo] ▶ sample " .. sampleCount .. " sent — check Live in browser")
end)

callbacks.Register("Unload", TAG, function()
	local ok, sid = Profiler.EndSession()
	package.loaded[LOAD_KEY] = nil
	if ok then
		print("[live_demo] Saved: flame_graphs/" .. tostring(sid))
	else
		print("[live_demo] Export failed: " .. tostring(sid))
	end
end)

print("")
print("  LIVE DEMO — open http://127.0.0.1:9876/ and click LIVE")
print("  Then move in TF2. Console prints each sample.")
print("  Unload script only when finished watching Live.")
print("")
