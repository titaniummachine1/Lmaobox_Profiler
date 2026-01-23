--[[
    PROFILER EXAMPLE - Fast Players Module Profiling
    Real-world test showing natural microsecond variance
]]

local SCRIPT_TAG = "fast_players_profile"

-- Unload existing instance
if _G.FAST_PLAYERS_PROFILE_LOADED then
	print("[FastPlayers Profile] Unloading previous instance...")
	callbacks.Unregister("CreateMove", SCRIPT_TAG)
	callbacks.Unregister("Draw", SCRIPT_TAG)
	callbacks.Unregister("Unload", SCRIPT_TAG)
	_G.FAST_PLAYERS_PROFILE_LOADED = false
	collectgarbage("collect")
end

-- Load profiler and fast_players
local Profiler = require("Profiler")
local FastPlayers = require("fast_players")

Profiler.SetVisible(true)
Profiler.SetMeasurementMode("tick")

_G.FAST_PLAYERS_PROFILE_LOADED = true

-- CreateMove callback - profile real fast_players usage
local function onCreateMove(cmd)
	Profiler.SetMeasurementMode("tick")

	-- Skip if paused
	if Profiler.IsPaused and Profiler.IsPaused() then
		return
	end

	Profiler.Begin("FastPlayers.Total")

	-- Invalidate cache each tick (forces rebuild)
	Profiler.Begin("FastPlayers.Invalidate")
	FastPlayers.Invalidate()
	Profiler.End("FastPlayers.Invalidate")

	-- Get all players (triggers full rebuild)
	Profiler.Begin("FastPlayers.GetAll")
	local allPlayers = FastPlayers.GetAll()
	Profiler.End("FastPlayers.GetAll")

	-- Get enemies (uses cached data)
	Profiler.Begin("FastPlayers.GetEnemies")
	local enemies = FastPlayers.GetEnemies()
	Profiler.End("FastPlayers.GetEnemies")

	-- Get teammates (uses cached data)
	Profiler.Begin("FastPlayers.GetTeammates")
	local teammates = FastPlayers.GetTeammates()
	Profiler.End("FastPlayers.GetTeammates")

	-- Iterate through all players (simulates real usage)
	Profiler.Begin("FastPlayers.Iteration")
	local validCount = 0
	for i = 1, #allPlayers do
		local ply = allPlayers[i]
		if ply and ply:IsValid() and ply:IsAlive() then
			validCount = validCount + 1
			-- Simulate some work
			local _ = ply:GetAbsOrigin()
			local _ = ply:GetHealth()
		end
	end
	Profiler.End("FastPlayers.Iteration")

	-- Test GetLocal (single lookup)
	Profiler.Begin("FastPlayers.GetLocal")
	local localPly = FastPlayers.GetLocal()
	Profiler.End("FastPlayers.GetLocal")

	Profiler.End("FastPlayers.Total")
end

-- Draw callback
local function onDraw()
	Profiler.Draw()
end

-- Unload callback
local function onUnload()
	print("[FastPlayers Profile] unloaded")
	Profiler.SetVisible(false)
	Profiler.Shutdown()
	_G.FAST_PLAYERS_PROFILE_LOADED = false
end

-- Register callbacks
callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, onUnload)

print("[FastPlayers Profile] loaded. Profiling real fast_players module usage.")
print("  - You should see natural µs-level variance (e.g., 127.532µs, 143.871µs)")
print("  - Not artificial clamping like synthetic loops")
