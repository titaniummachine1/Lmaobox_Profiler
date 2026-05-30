--[[
    Minimal flame graph smoke test (one shot on load).
]]

local SCRIPT_NAME = "test_flamegraphs"
local FLAME_GRAPHS_ROOT = "C:\\gitProjects\\profiler\\timing_collector\\flame_graphs"
local LOAD_KEY = "profiler.test_flamegraphs.v1"

if package.loaded[LOAD_KEY] then
	return
end

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")
Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[test_flamegraphs] run_collector.bat first")
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
task("buildLists", 25)
Profiler.EndTick()
Profiler.EndSession()

package.loaded[LOAD_KEY] = true
print("[test_flamegraphs] " .. FLAME_GRAPHS_ROOT .. "\\" .. tostring(sid))
