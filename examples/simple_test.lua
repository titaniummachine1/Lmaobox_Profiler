--[[
    Dead-simple profiler test — runs ONCE on lua_load. No CreateMove/Draw hooks.

    1. timing_collector\run_collector.bat
    2. lua_load simple_test
    3. Open the folder it prints -> tick.speedscope.json on speedscope.app
]]

local SCRIPT_NAME = "simple_test"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.simple_test.v1"

if package.loaded[LOAD_KEY] then
	print("[simple_test] Already ran.")
	return
end

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[simple_test] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[simple_test] Start run_collector.bat first.")
	return
end

local sessionId = Profiler.GetSessionID()

local function profileTask(name, times)
	Profiler.Begin(name)
	for i = 1, times do
		local _ = i + 1
	end
	Profiler.End(name)
end

Profiler.BeginTick()
profileTask("setupBones", 50)
profileTask("cachePlayers", 30)
profileTask("readConfig", 10)
Profiler.EndTick()

Profiler.EndSession()
package.loaded[LOAD_KEY] = true

print("============================================================")
print("[simple_test] Done.")
print("  " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sessionId))
print("  tick.speedscope.json -> https://www.speedscope.app")
print("============================================================")
