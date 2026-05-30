--[[
    Same as simple_test but with one extra nested task. Still one shot on load.

    1. Double-click timing_collector\run\timing_collector.exe
    2. lua_load example
]]

local SCRIPT_NAME = "example"
package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

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

local ok, sessionId = Profiler.EndSession()

if not ok then
	print("[Profiler] FAILED: " .. tostring(sessionId))
	return
end
print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
