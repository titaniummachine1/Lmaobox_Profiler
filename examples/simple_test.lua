--[[
    One-shot test. Deploy: npm run bundle-deploy  ->  %%LOCALAPPDATA%%\lua\Profiler.lua
    1. Double-click timing_collector\timing_collector.exe
    2. lua_load simple_test
]]

local SCRIPT_NAME = "simple_test"

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[simple_test] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript(SCRIPT_NAME)
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local function profileTask(name, times)
	Profiler.Begin(name)
	local acc = 0
	for i = 1, times do
		acc = acc + i * i
	end
	-- prevent zero-ns spans (empty loops can open+close in one timestamp)
	local _ = acc
	Profiler.End(name)
end

Profiler.BeginTick()
profileTask("setupBones", 50)
profileTask("cachePlayers", 30)
profileTask("readConfig", 10)
Profiler.EndTick()

local ok, sessionId = Profiler.EndSession()

if not ok then
	print("[Profiler] FAILED: " .. tostring(sessionId))
	return
end

print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
print("[Profiler] Open that file at https://www.speedscope.app")
