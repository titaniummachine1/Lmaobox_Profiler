--[[
    One-shot profiler test (runs once on lua_load — no callbacks).

    Lmaobox rules (see MCP pcall policy):
    - No BeginFrame outside Draw callback (tick-only on load).
    - No pcall around Profiler/engine calls.
    - http.Get only inside Profiler (pcall on IO boundary).

    1. timing_collector\run_collector.bat
    2. lua_load simple_test
    3. Open folder printed below -> tick.speedscope.json at speedscope.app
]]

local SCRIPT_NAME = "simple_test"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.simple_test.loaded"

if package.loaded[LOAD_KEY] then
	print("[simple_test] Already ran — reload ignored.")
	return
end
package.loaded[LOAD_KEY] = true

package.loaded["Profiler"] = nil

local Profiler = require("Profiler")
if type(Profiler.BindScript) ~= "function" then
	print("[simple_test] Old Profiler.lua — run: npm run bundle-deploy")
	return
end

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

local sessionId = nil

if not Profiler.BeginSession() then
	print("[simple_test] FAILED: timing_collector offline. Run run_collector.bat first.")
	return
end

sessionId = Profiler.GetSessionID()

-- Tick-only on load (frame profiling belongs in Draw callback).
Profiler.BeginTick()
Profiler.Begin("LoadTest")
for i = 1, 1500 do
	local _ = math.sqrt(i) * math.sin(i * 0.01)
end
Profiler.End("LoadTest")
Profiler.EndTick()

Profiler.EndSession()

print("============================================================")
print("[simple_test] Done.")
if sessionId then
	print("[simple_test] EXPLORER:")
	print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sessionId))
	print("[simple_test] Open: tick.speedscope.json at https://www.speedscope.app")
else
	print("[simple_test] Check: " .. FLAME_GRAPHS_ROOT)
end
print("============================================================")
