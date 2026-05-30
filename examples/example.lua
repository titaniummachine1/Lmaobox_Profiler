--[[
    Same as simple_test but with one extra nested task. Still one shot on load.

    1. run_collector.bat
    2. lua_load example
]]

local SCRIPT_NAME = "example"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.example.v1"

if package.loaded[LOAD_KEY] then
	print("[example] Already ran.")
	return
end

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[example] Start run_collector.bat first.")
	return
end

local sessionId = Profiler.GetSessionID()

local function profileTask(name, times)
	Profiler.Begin(name)
	for i = 1, times do
		local _ = i * i
	end
	Profiler.End(name)
end

Profiler.BeginTick()
profileTask("setupBones", 50)

Profiler.Begin("aimbotTick")
profileTask("findTarget", 20)
profileTask("smoothAngles", 15)
Profiler.End("aimbotTick")

profileTask("cleanup", 5)
Profiler.EndTick()

Profiler.EndSession()
package.loaded[LOAD_KEY] = true

print("============================================================")
print("[example] Done. Graphs:")
print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sessionId))
print("============================================================")
