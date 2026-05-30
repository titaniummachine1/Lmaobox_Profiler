--[[
    Profile fast_players every ~1s. No Unregister / _G (Lmaobox policy).
]]

local TAG = "fast_players_profile"
local LOAD_KEY = "profiler.fast_players_profile.v1"
local TICKS_PER_SAMPLE = 66

if package.loaded[LOAD_KEY] then
	print("[fast_players_profile] Already loaded.")
	return
end
package.loaded[LOAD_KEY] = true

package.loaded["Profiler"] = nil
local Profiler = require("Profiler")
Profiler.BindScript("fast_players_profile")
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

local FastPlayers = nil
local ok, mod = pcall(require, "fast_players")
if ok then
	FastPlayers = mod
end

local tickCount = 0

callbacks.Register("CreateMove", TAG, function()
	tickCount = tickCount + 1
	if tickCount % TICKS_PER_SAMPLE ~= 0 then
		return
	end

	Profiler.BeginTick()
	Profiler.Begin("FastPlayers.Total")

	if FastPlayers and FastPlayers.Update then
		Profiler.Begin("Update")
		FastPlayers.Update()
		Profiler.End("Update")
	end

	if FastPlayers and FastPlayers.GetAll then
		Profiler.Begin("GetAll")
		local _ = FastPlayers.GetAll()
		Profiler.End("GetAll")
	end

	Profiler.End("FastPlayers.Total")
	Profiler.EndTick()
end)

callbacks.Register("Unload", TAG, function()
	local ok, sessionId = Profiler.EndSession()
	package.loaded[LOAD_KEY] = nil
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end)

print("[fast_players_profile] Sampling every " .. TICKS_PER_SAMPLE .. " ticks — unload to export.")
print("[fast_players_profile] fast_players: " .. (FastPlayers and "yes" or "no"))
