--[[
    Profile fast_players every ~1s.
]]

local TAG = "fast_players_profile"
local TICKS_PER_SAMPLE = 66

local tickCount = 0
local FastPlayers = nil
local Profiler

local function onCreateMove(_cmd)
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
end

local function onUnload()
	local ok, sessionId = Profiler.EndSession()
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end

callbacks.Unregister("CreateMove", TAG)
callbacks.Unregister("Unload", TAG)

package.loaded["Profiler"] = nil
Profiler = require("Profiler")

Profiler.BindScript("fast_players_profile")
Profiler.SetEnabled(true)

local ok, mod = pcall(require, "fast_players")
if ok then
	FastPlayers = mod
end

if Profiler.GetSessionID() then
	Profiler.EndSession()
end

if not Profiler.BeginSession() then
	print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
	return
end

callbacks.Register("CreateMove", TAG, onCreateMove)
callbacks.Register("Unload", TAG, onUnload)

print("[fast_players_profile] Sampling every " .. TICKS_PER_SAMPLE .. " ticks — unload to export.")
print("[fast_players_profile] fast_players: " .. (FastPlayers and "yes" or "no"))
