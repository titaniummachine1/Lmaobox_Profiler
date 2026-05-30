--[[
    Example: profile optional fast_players module if present.
]]

local TAG = "fast_players_profile"

local function cleanup()
	callbacks.Unregister("CreateMove", TAG)
	callbacks.Unregister("Draw", TAG)
	callbacks.Unregister("Unload", TAG)
end

if _G.FAST_PLAYERS_PROFILE_LOADED then
	cleanup()
	_G.FAST_PLAYERS_PROFILE_LOADED = false
end

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

_G.FAST_PLAYERS_PROFILE_LOADED = true

callbacks.Register("CreateMove", TAG, function(cmd)
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

callbacks.Register("Draw", TAG, function()
	Profiler.BeginFrame()
	Profiler.EndFrame()
end)

callbacks.Register("Unload", TAG, function()
	local ok, sessionId = Profiler.EndSession()
	cleanup()
	_G.FAST_PLAYERS_PROFILE_LOADED = false
	if ok then
		print("[Profiler] OK flame_graphs/" .. tostring(sessionId) .. "/tick.speedscope.json")
	else
		print("[Profiler] FAILED: " .. tostring(sessionId))
	end
end)

print("[fast_players_profile] Recording every tick — unload to export.")
print("[fast_players_profile] fast_players: " .. (FastPlayers and "yes" or "no"))
