--[[
    Tick + frame in one shot (frame block still runs at load; real games use Draw callback).

    1. run_collector.bat
    2. lua_load dual_context_example
]]

local SCRIPT_NAME = "dual_context_example"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.dual_context.v1"

if package.loaded[LOAD_KEY] then
	return
end

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")
Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[dual_context] run_collector.bat first")
	return
end

local sid = Profiler.GetSessionID()

local function task(name, n)
	Profiler.Begin(name)
	for i = 1, n do
		local _ = i
	end
	Profiler.End(name)
end

Profiler.BeginTick()
task("setupBones", 50)
Profiler.EndTick()

Profiler.BeginFrame()
task("drawEsp", 30)
Profiler.EndFrame()

Profiler.EndSession()
package.loaded[LOAD_KEY] = true

print("[dual_context] tick.* + frame.* in:")
print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sid))
