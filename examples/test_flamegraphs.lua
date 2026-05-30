--[[
    Primary profiler test — produces visible flame_graphs output.

    SETUP
    1. Run:  timing_collector\timing_collector.exe
    2. Deploy: examples\deployexamples.bat  (or BundleAndDeploy.bat)
    3. In Lmaobox console:  lua_load test_flamegraphs

    RESULTS (next to timing_collector.exe)
    timing_collector\flame_graphs\<session_id>\
      tick.speedscope.json   -> https://www.speedscope.app
      tick.folded.txt
      frame.speedscope.json
      frame.folded.txt
      session.meta.json

    SESSION ENDS WHEN (any of these):
    - You unload this script (Profiler.EndSession on Unload)
    - You lua_load another script that uses Profiler (new session begins)
    - No profiling HTTP traffic for 3 seconds (idle timeout)
]]

local TAG = "test_flamegraphs"

local function cleanupCallbacks()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Draw", TAG)
	callbacks.Unregister("Unload", TAG)
end

if _G.TEST_FLAMEGRAPHS_LOADED then
	cleanupCallbacks()
	if _G.TEST_FLAMEGRAPHS_PROFILER then
		_G.TEST_FLAMEGRAPHS_PROFILER.EndSession()
	end
	_G.TEST_FLAMEGRAPHS_LOADED = false
end

local Profiler = require("Profiler")
Profiler.SetEnabled(true)
_G.TEST_FLAMEGRAPHS_PROFILER = Profiler
_G.TEST_FLAMEGRAPHS_LOADED = true

local tickCount = 0
local frameCount = 0
local printedSession = false

local function burn(name, iterations)
	Profiler.Begin(name)
	local acc = 0
	for i = 1, iterations do
		acc = acc + math.sqrt(i) * math.sin(i * 0.0007) + math.cos(i * 0.0013)
	end
	Profiler.End(name)
	return acc
end

local function printBanner()
	print("============================================================")
	print("[test_flamegraphs] Profiler test loaded")
	print("")
	if Profiler.IsCollectorAvailable() then
		print("  Collector: OK (127.0.0.1:9876)")
	else
		print("  Collector: NOT REACHABLE — start timing_collector.exe first")
	end
	local sid = Profiler.GetSessionID()
	if sid then
		print("  Session:   " .. sid)
	end
	print("")
	print("  Play in-game for a few seconds (CreateMove + Draw must run).")
	print("  Then either:")
	print("    - Unload this script, OR")
	print("    - Stop moving / tab out for 3+ seconds (idle export)")
	print("")
	print("  Open output folder:")
	print("    timing_collector\\flame_graphs\\<session_id>\\")
	print("  View tick.speedscope.json in https://www.speedscope.app")
	print("============================================================")
end

local function onCreateMove(cmd)
	Profiler.BeginTick()
	Profiler.Begin("TickRoot")
	burn("HeavyMath", 60000)
	burn("ExtraMath", 15000)
	Profiler.Begin("NestedWork")
	burn("InnerLoop", 8000)
	Profiler.End("NestedWork")
	Profiler.End("TickRoot")
	Profiler.EndTick()

	tickCount = tickCount + 1
	if not printedSession and Profiler.GetSessionID() then
		printedSession = true
		print(string.format("[test_flamegraphs] tick #%d  session=%s", tickCount, Profiler.GetSessionID()))
	end
end

local function onDraw()
	Profiler.BeginFrame()
	Profiler.Begin("FrameRoot")
	burn("FrameMath", 12000)
	Profiler.End("FrameRoot")
	Profiler.EndFrame()

	frameCount = frameCount + 1
end

local function onUnload()
	print(string.format("[test_flamegraphs] Unload — ticks=%d frames=%d — ending session", tickCount, frameCount))
	Profiler.EndSession()
	cleanupCallbacks()
	_G.TEST_FLAMEGRAPHS_LOADED = false
	_G.TEST_FLAMEGRAPHS_PROFILER = nil
	print("[test_flamegraphs] Check timing_collector\\flame_graphs\\ for exported files (end_reason=api in meta)")
end

callbacks.Register("CreateMove", TAG, onCreateMove)
callbacks.Register("Draw", TAG, onDraw)
callbacks.Register("Unload", TAG, onUnload)

printBanner()
