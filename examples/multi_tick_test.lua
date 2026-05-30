--[[
    Profile ~1 CreateMove tick per second (avoids blocking http.Get storm).
    Unload script to export. No callbacks.Unregister (Lmaobox policy — crashes).

    1. Double-click timing_collector\run\timing_collector.exe
    2. lua_load multi_tick_test
    3. Play a few seconds, unload script
]]

local TAG = "multi_tick_test"
local LOAD_KEY = "profiler.multi_tick_test.v1"
local TICKS_PER_SAMPLE = 66

if package.loaded[LOAD_KEY] then
	print("[multi_tick_test] Already loaded — restart game or use another TAG to load twice.")
	return
end
package.loaded[LOAD_KEY] = true

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")

if type(Profiler.BindScript) ~= "function" then
	print("[multi_tick_test] Run: npm run bundle-deploy")
	return
end

Profiler.BindScript("multi_tick_test")
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local tickCount = 0

local function profileTask(name, times)
	Profiler.Begin(name)
	local acc = 0
	for i = 1, times do
		acc = acc + i * i
	end
	local _ = acc
	Profiler.End(name)
end

callbacks.Register("CreateMove", TAG, function()
	tickCount = tickCount + 1
	if tickCount % TICKS_PER_SAMPLE ~= 0 then
		return
	end

	Profiler.BeginTick()
	profileTask("setupBones", 40)
	profileTask("cachePlayers", 25)
	profileTask("readConfig", 15)
	Profiler.EndTick()
end)

callbacks.Register("Unload", TAG, function()
	local ok, sessionId = Profiler.EndSession()
	package.loaded[LOAD_KEY] = nil
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
		print(
			"[Profiler] ~"
				.. tostring(math.floor(tickCount / TICKS_PER_SAMPLE))
				.. " ticks — use Left Heavy in speedscope to compare cost"
		)
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end)

print("[multi_tick_test] Sampling every " .. TICKS_PER_SAMPLE .. " ticks — play, then unload to export.")
