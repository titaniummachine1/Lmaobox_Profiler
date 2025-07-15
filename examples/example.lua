-- Lmaobox Profiler Example
-- Save as example.lua in %localappdata%
-- Load with: lua_load example.lua

-- Clear any existing profiler before loading new one
if package.loaded["Profiler"] then
	local oldProfiler = package.loaded["Profiler"]
	if oldProfiler and oldProfiler.Unload then
		oldProfiler.Unload()
	end
end

-- Load the bundled Profiler library
local Profiler = require("Profiler")

-- Enable the profiler with optimal settings for Lmaobox
Profiler.SetVisible(true)
Profiler.SetSortMode("size") -- Show biggest components first
Profiler.SetWindowSize(60) -- Average over 60 frames for smooth data

print("✅ Lmaobox Profiler enabled! Memory and performance monitoring active.")

--[[
    USAGE:
    Profiler.BeginSystem("name") - Start system profiling
    Profiler.EndSystem() - End system profiling
    Profiler.Begin("name") - Start component profiling
    Profiler.End() - End component profiling
]]

-- Create fonts for our example scripts (like the community examples)
local consolas = draw.CreateFont("Consolas", 17, 500)
local verdana = draw.CreateFont("Verdana", 16, 800)

-- Variables for our example features
local current_fps = 0
local damage_events = {}

-- FPS Counter (based on x6h's example) - Profiled version
local function ProfiledFPSCounter()
	-- This will automatically be assigned to "misc" system since no system is active
	Profiler.Begin("fps_counter")

	draw.SetFont(consolas)
	draw.Color(255, 255, 255, 255)

	-- Update fps every 100 frames (expensive operation)
	if globals.FrameCount() % 100 == 0 then
		current_fps = math.floor(1 / globals.FrameTime())
	end

	draw.Text(5, 5, "[lmaobox | fps: " .. tostring(current_fps) .. " | profiler: ON]")

	Profiler.End()
end

-- Basic Player ESP (based on community example) - Profiled version
local function ProfiledPlayerESP()
	Profiler.Begin("player_esp")

	if engine.Con_IsVisible() or engine.IsGameUIVisible() then
		Profiler.End()
		return
	end

	-- This is expensive - finding all players every frame
	local players = entities.FindByClass("CTFPlayer")

	for i, p in ipairs(players) do
		if p:IsAlive() and not p:IsDormant() then
			local screenPos = client.WorldToScreen(p:GetAbsOrigin())
			if screenPos ~= nil then
				draw.SetFont(verdana)
				draw.Color(255, 255, 255, 255)
				draw.Text(screenPos[1], screenPos[2], p:GetName())
			end
		end
	end

	Profiler.End()
end

-- Damage Logger (based on @RC's example) - Profiled version
local function ProfiledDamageLogger(event)
	Profiler.Begin("damage_logger")

	if event:GetName() == "player_hurt" then
		local localPlayer = entities.GetLocalPlayer()
		if not localPlayer then
			Profiler.End()
			return
		end

		local victim = entities.GetByUserID(event:GetInt("userid"))
		local health = event:GetInt("health")
		local attacker = entities.GetByUserID(event:GetInt("attacker"))
		local damage = event:GetInt("damageamount")

		if attacker and localPlayer:GetIndex() == attacker:GetIndex() then
			-- Store damage event (this uses memory)
			table.insert(damage_events, {
				victim = victim:GetName(),
				damage = damage,
				health = health,
				time = globals.RealTime(),
			})

			-- Keep only last 10 damage events to prevent memory bloat
			if #damage_events > 10 then
				table.remove(damage_events, 1)
			end

			print(
				"You hit "
					.. victim:GetName()
					.. " for "
					.. tostring(damage)
					.. "HP (health: "
					.. tostring(health)
					.. ")"
			)
		end
	end

	Profiler.End()
end

-- Example aimbot logic (expensive computation)
local function ProfiledAimbot(cmd)
	Profiler.Begin("aimbot")

	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer or not localPlayer:IsAlive() then
		Profiler.End()
		return
	end

	-- Expensive: scan for enemies
	local players = entities.FindByClass("CTFPlayer")
	local bestTarget = nil
	local bestFOV = 180

	for i, player in ipairs(players) do
		if player:IsAlive() and not player:IsDormant() and player:GetTeamNumber() ~= localPlayer:GetTeamNumber() then
			-- Expensive: FOV calculation
			local fov = math.random() * 60 -- Simulate FOV calculation
			if fov < bestFOV then
				bestFOV = fov
				bestTarget = player
			end
		end
	end

	-- Simulate aim adjustment (expensive math)
	if bestTarget then
		local result = 0
		for i = 1, 100 do
			result = result + math.sin(i) * math.cos(i) -- Simulate heavy computation
		end
	end

	Profiler.End()
end

-- Example movement assistance
local function ProfiledMovement(cmd)
	Profiler.Begin("movement")

	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer then
		Profiler.End()
		return
	end

	-- Simulate strafe calculation (expensive)
	local velocity = localPlayer:EstimateAbsVelocity()
	if velocity then
		-- Heavy computation for movement
		for i = 1, 50 do
			math.sqrt(velocity:Length() + i)
		end
	end

	Profiler.End()
end

-- Register callbacks
callbacks.Unregister("CreateMove", "profiled_createmove")
callbacks.Unregister("Draw", "profiled_draw")
callbacks.Unregister("FireGameEvent", "profiled_events")

callbacks.Register("CreateMove", "profiled_createmove", function(cmd)
	Profiler.BeginSystem("oncreatemove")
	ProfiledAimbot(cmd)
	ProfiledMovement(cmd)
	Profiler.EndSystem()
end)

callbacks.Register("Draw", "profiled_draw", function()
	Profiler.BeginSystem("ondraw")
	ProfiledFPSCounter()
	ProfiledPlayerESP()
	Profiler.Draw()
	Profiler.EndSystem()
end)

callbacks.Register("FireGameEvent", "profiled_events", function(event)
	Profiler.BeginSystem("onevent")
	ProfiledDamageLogger(event)
	Profiler.EndSystem()
end)
