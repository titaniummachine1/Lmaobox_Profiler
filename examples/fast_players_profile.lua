--[[
    PROFILER EXAMPLE - Fast Players Module Profiling
    Real-world test showing natural microsecond variance
]]

_G.FAST_PLAYERS_PROFILE_LOADED = nil

local SCRIPT_TAG = "fast_players_profile"

-- Unload existing instance
if FAST_PLAYERS_PROFILE_LOADED then
	print("[FastPlayers Profile] Unloading previous instance...")
	callbacks.Unregister("CreateMove", SCRIPT_TAG)
	callbacks.Unregister("Draw", SCRIPT_TAG)
	callbacks.Unregister("Unload", SCRIPT_TAG)
	FAST_PLAYERS_PROFILE_LOADED = false
	collectgarbage("collect")
end

-- Load profiler and fast_players
local Profiler = require("Profiler")
local FastPlayers = require("fast_players")

-- Trace mask constants
local MASK_SHOT_HULL = 0x40040000

FAST_PLAYERS_PROFILE_LOADED = true

-- CreateMove callback - profile real fast_players usage
local function onCreateMove(cmd)
	Profiler.SetContext("tick")

	-- Skip if paused
	if Profiler.IsPaused and Profiler.IsPaused() then
		return
	end

	Profiler.Begin("FastPlayers.Total")

	-- Update cache (triggers rebuild if needed)
	Profiler.Begin("Update")
	FastPlayers.Update()
	Profiler.End("Update")

	Profiler.Begin("SimpleTest")
	variable = 1 + 1
	Profiler.End("SimpleTest")

	-- Trace line performance test (safe version)
	local me = entities.GetLocalPlayer()
	if me then
		local source = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
		local destination = source + engine.GetViewAngles():Forward() * 1000
		Profiler.Begin("TraceLine")
		local trace = engine.TraceLine(source, destination, MASK_SHOT_HULL)
		Profiler.End("TraceLine")
	end

	-- Get all players (uses cached data)
	Profiler.Begin("GetAll")
	local allPlayers = FastPlayers.GetAll()
	Profiler.End("GetAll")

	-- Get enemies (uses cached data)
	Profiler.Begin("GetEnemies")
	local enemies = FastPlayers.GetEnemies()
	Profiler.End("GetEnemies")

	-- Get teammates (uses cached data)
	Profiler.Begin("GetTeammates")
	local teammates = FastPlayers.GetTeammates()
	Profiler.End("GetTeammates")

	-- Iterate through all players (simulates real usage)
	Profiler.Begin("Iteration")
	local validCount = 0
	local maxIterations = math.max(1, math.floor(#allPlayers / 10))
	for i = 1, maxIterations do
		local ply = allPlayers[i]
		if ply and ply:IsValid() and ply:IsAlive() then
			validCount = validCount + 1
			local _ = ply:GetAbsOrigin()
			local _ = ply:GetHealth()
		end
	end
	Profiler.End("Iteration")

	-- Test GetLocal (single lookup)
	Profiler.Begin("GetLocal")
	local localPly = FastPlayers.GetLocal()
	Profiler.End("GetLocal")

	Profiler.End("FastPlayers.Total")
end

-- Draw callback
local function onDraw()
	Profiler.SetContext("frame")
	Profiler.Draw()
end

-- Unload callback
local function onUnload()
	print("[FastPlayers Profile] unloaded")
	Profiler.SetVisible(false)
	Profiler.Shutdown()
	FAST_PLAYERS_PROFILE_LOADED = false
end

-- Register callbacks
callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, onUnload)

print("[FastPlayers Profile] loaded. Profiling real fast_players module usage.")
print("  - Function names are simplified: 'FastPlayers.Update' shows as 'Update'")
print("  - Automatic nesting: all work under 'FastPlayers.Total' becomes children")
print("  - Smart text layout: names prioritized, time/memory shown if space allows")
print("  - Data preserved on unpause - no more crashes or data loss!")
