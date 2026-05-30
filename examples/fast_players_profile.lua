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
	Profiler.EndSession()
	cleanup()
	_G.FAST_PLAYERS_PROFILE_LOADED = false
end)

print("[fast_players_profile] Loaded" .. (FastPlayers and " with fast_players" or " (no fast_players module)"))
print("[fast_players_profile] session=" .. tostring(Profiler.GetSessionID()))
