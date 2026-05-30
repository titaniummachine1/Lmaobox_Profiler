--[[
    Quick profiler test (lightweight — will not freeze the game).

    1. Run:  C:\gitProjects\profiler\timing_collector\run_collector.bat
    2. In Lmaobox console:  lua_load simple_test
    3. Join a match / move around for a few seconds
    4. Unload script OR stand still 3+ seconds

    FLAME GRAPHS LOCATION (open in File Explorer):
      C:\gitProjects\profiler\timing_collector\flame_graphs\<session_id>\
    Files:
      tick.speedscope.json  -> drag into https://www.speedscope.app
      tick.folded.txt
      frame.speedscope.json
      frame.folded.txt
      session.meta.json     -> shows output_dir and end_reason
]]

local TAG = "profiler_simple_test"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"

local function cleanup()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Draw", TAG)
	callbacks.Unregister("Unload", TAG)
end

if _G.PROFILER_SIMPLE_TEST then
	cleanup()
	_G.PROFILER_SIMPLE_TEST = false
end

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")
Profiler.SetEnabled(true)
_G.PROFILER_SIMPLE_TEST = true

local function burn(name, count)
	Profiler.Begin(name)
	for i = 1, count do
		local _ = math.sqrt(i) * math.sin(i * 0.01)
	end
	Profiler.End(name)
end

local function safeTick(cmd)
	local ok, err = pcall(function()
		Profiler.BeginTick()
		Profiler.Begin("TickTotal")
		burn("Math", 2000)
		Profiler.End("TickTotal")
		Profiler.EndTick()
	end)
	if not ok then
		print("[simple_test] CreateMove error: " .. tostring(err))
	end
end

local function safeDraw()
	local ok, err = pcall(function()
		Profiler.BeginFrame()
		Profiler.Begin("FrameTotal")
		burn("FrameMath", 800)
		Profiler.End("FrameTotal")
		Profiler.EndFrame()
	end)
	if not ok then
		print("[simple_test] Draw error: " .. tostring(err))
	end
end

callbacks.Register("CreateMove", TAG, safeTick)
callbacks.Register("Draw", TAG, safeDraw)
callbacks.Register("Unload", TAG, function()
	local sid = Profiler.GetSessionID()
	Profiler.EndSession()
	cleanup()
	_G.PROFILER_SIMPLE_TEST = false
	print("============================================================")
	print("[simple_test] Session ended.")
	if sid then
		print("[simple_test] Open this folder in Explorer:")
		print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. sid)
		print("[simple_test] Open tick.speedscope.json at https://www.speedscope.app")
	else
		print("[simple_test] No session (was timing_collector.exe running?)")
		print("[simple_test] Start: timing_collector\\run_collector.bat")
	end
	print("============================================================")
end)

print("============================================================")
print("[simple_test] Loaded")
if Profiler.IsCollectorAvailable() then
	print("[simple_test] Collector: OK")
	print("[simple_test] Session:  " .. tostring(Profiler.GetSessionID()))
else
	print("[simple_test] Collector: OFFLINE — run timing_collector\\run_collector.bat first")
end
print("[simple_test] Flame graphs root:")
print("  " .. FLAME_GRAPHS_ROOT)
print("[simple_test] Play in-game, then unload or wait 3s idle")
print("============================================================")
