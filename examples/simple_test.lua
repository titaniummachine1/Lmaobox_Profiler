--[[
    Quick smoke test — same pattern as test_flamegraphs, lighter CPU load.

    1. timing_collector.exe
    2. lua_load simple_test
    3. Move/play briefly, then unload OR wait 3s idle
]]

local TAG = "profiler_simple_test"

local function cleanup()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Draw", TAG)
	callbacks.Unregister("Unload", TAG)
end

if _G.PROFILER_SIMPLE_TEST then
	cleanup()
	_G.PROFILER_SIMPLE_TEST = false
end

local Profiler = require("Profiler")
Profiler.SetEnabled(true)
_G.PROFILER_SIMPLE_TEST = true

local function burn(name, count)
	Profiler.Begin(name)
	for i = 1, count do
		local _ = math.sqrt(i) * math.sin(i * 0.001)
	end
	Profiler.End(name)
end

callbacks.Register("CreateMove", TAG, function(cmd)
	Profiler.BeginTick()
	Profiler.Begin("TickTotal")
	burn("HeavyMath", 40000)
	burn("MoreMath", 8000)
	Profiler.End("TickTotal")
	Profiler.EndTick()
end)

callbacks.Register("Draw", TAG, function()
	Profiler.BeginFrame()
	Profiler.Begin("FrameTotal")
	burn("FrameMath", 10000)
	Profiler.End("FrameTotal")
	Profiler.EndFrame()
end)

callbacks.Register("Unload", TAG, function()
	print("[simple_test] EndSession — see flame_graphs folder")
	Profiler.EndSession()
	cleanup()
	_G.PROFILER_SIMPLE_TEST = false
end)

print("[simple_test] Loaded. Session=" .. tostring(Profiler.GetSessionID()))
print("[simple_test] Output: timing_collector\\flame_graphs\\<session_id>\\")
