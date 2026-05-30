--[[
    Profiler example — nested spans in tick and frame contexts.

    1. Start timing_collector.exe
    2. lua_load example
    3. Play a few seconds; unload script or wait 3s with no callbacks for idle export
]]

local SCRIPT_TAG = "profiler_example"

local function cleanup()
	callbacks.Unregister("CreateMove", SCRIPT_TAG)
	callbacks.Unregister("Draw", SCRIPT_TAG)
	callbacks.Unregister("Unload", SCRIPT_TAG)
end

if _G.PROFILER_EXAMPLE_LOADED then
	cleanup()
	_G.PROFILER_EXAMPLE_LOADED = false
end

local Profiler = require("Profiler")
Profiler.SetEnabled(true)
_G.PROFILER_EXAMPLE_LOADED = true

local function heavyWork(label, iterations)
	Profiler.Begin(label)
	local sum = 0
	for i = 1, iterations do
		sum = sum + math.sin(i * 0.01) * math.cos(i * 0.02)
	end
	Profiler.End(label)
	return sum
end

local function onCreateMove(cmd)
	Profiler.BeginTick()
	Profiler.Begin("GameLogic")
	heavyWork("PathMath", 8000)
	heavyWork("Validation", 3000)
	Profiler.End("GameLogic")
	Profiler.EndTick()
end

local function onDraw()
	Profiler.BeginFrame()
	Profiler.Begin("DrawWork")
	heavyWork("DrawPrep", 2000)
	Profiler.End("DrawWork")
	Profiler.EndFrame()
end

callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, function()
	Profiler.EndSession()
	cleanup()
	_G.PROFILER_EXAMPLE_LOADED = false
	print("[example] Session ended — open timing_collector\\flame_graphs\\")
end)

print("[Profiler Example] session=" .. tostring(Profiler.GetSessionID()))
print("[Profiler Example] flame_graphs next to timing_collector.exe")
