--[[
    Multi-tick profile for Live + saved flame graphs.

    BEFORE playing:
      1. Double-click timing_collector\run\timing_collector.exe
      2. Open http://127.0.0.1:9876/ → click **Live** (top-left)
      3. lua_load multi_tick_test

    Play in TF2 — console prints "sample N" when each tick is recorded.
    Unload script to export → session appears under Saved sessions.

    Nested spans: CreateMove → setupBones / cachePlayers / readConfig
]]

local TAG = "multi_tick_test"
local LOAD_KEY = "profiler.multi_tick_test.v2"
local TICKS_PER_SAMPLE = 22 -- ~3 samples/sec at 66 tickrate (was 66 = ~1/sec, easy to miss in Live)

if package.loaded[LOAD_KEY] then
	print("[multi_tick_test] Already loaded — unload first, or restart game.")
	return
end
package.loaded[LOAD_KEY] = true

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[multi_tick_test] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript("multi_tick_test")
Profiler.SetEnabled(true)

if not Profiler.IsCollectorAvailable() then
	print("[multi_tick_test] FAILED: timing_collector not running on http://127.0.0.1:9876")
	print("  Double-click timing_collector\\run\\timing_collector.exe")
	return
end

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local tickCount = 0
local sampleCount = 0

local function profileTick()
	Profiler.BeginTick()
	Profiler.Begin("CreateMove")

	Profiler.Begin("setupBones")
	local acc = 0
	for i = 1, 40 do
		acc = acc + i * i
	end
	Profiler.End()

	Profiler.Begin("cachePlayers")
	for i = 1, 25 do
		acc = acc + i * i
	end
	Profiler.End()

	Profiler.Begin("readConfig")
	for i = 1, 15 do
		acc = acc + i * i
	end
	Profiler.End()

	local _ = acc
	Profiler.End() -- CreateMove
	Profiler.EndTick()
end

callbacks.Register("CreateMove", TAG, function()
	tickCount = tickCount + 1
	if tickCount % TICKS_PER_SAMPLE ~= 0 then
		return
	end

	sampleCount = sampleCount + 1
	profileTick()
	print(
		string.format(
			"[multi_tick_test] sample %d (tick %d) — Live panel should update",
			sampleCount,
			tickCount
		)
	)
end)

callbacks.Register("Unload", TAG, function()
	local ok, sessionId = Profiler.EndSession()
	package.loaded[LOAD_KEY] = nil
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
		print("[Profiler] ~" .. tostring(sampleCount) .. " ticks sampled — open Saved session in browser")
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end)

print("============================================================")
print("[multi_tick_test] Session active — keep script LOADED while testing Live")
print("[multi_tick_test] Browser: http://127.0.0.1:9876/  →  click LIVE (top-left)")
print("[multi_tick_test] Sampling every " .. TICKS_PER_SAMPLE .. " game ticks — move in-game")
print("============================================================")
