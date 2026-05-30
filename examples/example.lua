--[[
    Profiler example — in-game tick + frame profiling.

    1. timing_collector\run_collector.bat  (must be running)
    2. lua_load example
    3. Join a match / move (CreateMove + Draw must run)
    4. Unload script or wait 3s idle -> flame_graphs exported

    Output folder:
      C:\gitProjects\profiler\timing_collector\flame_graphs\<session_id>\
]]

local SCRIPT_TAG = "profiler_example"
local SCRIPT_NAME = "example"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.example.v1"

-- Top-level only (Lmaobox policy: no Unregister inside callbacks).
callbacks.Unregister("CreateMove", SCRIPT_TAG)
callbacks.Unregister("Draw", SCRIPT_TAG)
callbacks.Unregister("Unload", SCRIPT_TAG)

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[example] Old Profiler.lua — run: npm run bundle-deploy")
	return
end

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

local sessionOk = Profiler.BeginSession()
local sessionId = Profiler.GetSessionID()

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
	heavyWork("PathMath", 2000)
	heavyWork("Validation", 800)
	Profiler.End("GameLogic")
	Profiler.EndTick()
end

local function onDraw()
	Profiler.BeginFrame()
	Profiler.Begin("DrawWork")
	heavyWork("DrawPrep", 800)
	Profiler.End("DrawWork")
	Profiler.EndFrame()
end

local function onUnload()
	local sid = Profiler.GetSessionID() or sessionId
	Profiler.EndSession()
	print("============================================================")
	print("[example] Unloaded.")
	if sid then
		print("[example] OPEN:")
		print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sid))
		print("[example] tick.speedscope.json -> https://www.speedscope.app")
	else
		print("[example] No session — was run_collector.bat running?")
	end
	print("============================================================")
end

callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, onUnload)

package.loaded[LOAD_KEY] = true

print("============================================================")
print("[example] Loaded (script=" .. SCRIPT_NAME .. ")")
if sessionOk and sessionId then
	print("[example] Collector: OK")
	print("[example] Session:  " .. sessionId)
	print("[example] Join a match and move — then unload or wait 3s idle")
	print("[example] Graphs:")
	print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. sessionId)
else
	print("[example] Collector: OFFLINE (session=nil)")
	print("[example] Start: C:\\gitProjects\\profiler\\timing_collector\\run_collector.bat")
	print("[example] Then lua_load example again")
end
print("============================================================")
