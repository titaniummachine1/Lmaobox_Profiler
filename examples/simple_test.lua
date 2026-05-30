--[[
    One-shot export (no Live — ends immediately). For Live use live_demo or multi_tick_test.

    Deploy: npm run bundle-deploy  ->  %LOCALAPPDATA%\lua\Profiler.lua
    1. timing_collector\run\timing_collector.exe
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
Profiler.Begin("CreateMove")
profileTask("setupBones", 50)
profileTask("cachePlayers", 30)
profileTask("readConfig", 10)
Profiler.End() -- CreateMove
Profiler.EndTick()

local ok, sessionId = Profiler.EndSession()

if not ok then
	print("[Profiler] FAILED: " .. tostring(sessionId))
	return
end

print("[Profiler] OK — browser should open http://127.0.0.1:9876/")
print("[Profiler] session: " .. tostring(sessionId))
