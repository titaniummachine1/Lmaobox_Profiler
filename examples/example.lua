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
	Profiler.Begin("fps_counter")

	draw.SetFont(consolas)
	draw.Color(255, 255, 255, 255)

	-- Update fps every 100 frames (expensive operation)
	if globals.FrameCount() % 100 == 0 then
		current_fps = math.floor(1 / globals.FrameTime())
	end

	-- Random memory allocation to show variety
	local temp_data = {}
	for i = 1, math.random(5, 25) do
		temp_data[i] = "frame_" .. globals.FrameCount() .. "_" .. i
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

	-- Random extra computation to vary load
	local complexity = math.random(1, 10)
	local extra_data = {}
	for i = 1, complexity * 3 do
		extra_data[i] = {
			id = i,
			name = "player_data_" .. i,
			pos = { math.random(100, 800), math.random(100, 600) },
			active = math.random() > 0.5,
		}
	end

	for i, p in ipairs(players) do
		if p:IsAlive() and not p:IsDormant() then
			local screenPos = client.WorldToScreen(p:GetAbsOrigin())
			if screenPos ~= nil then
				draw.SetFont(verdana)
				draw.Color(255, 255, 255, 255)
				draw.Text(screenPos[1], screenPos[2], p:GetName())

				-- Random additional processing
				if math.random() > 0.7 then
					local health_info = "HP: " .. tostring(math.random(1, 100))
					extra_data[#extra_data + 1] = health_info
				end
			end
		end
	end

	Profiler.End()
end

-- Damage Logger (based on @RC's example) - Profiled version
local function ProfiledDamageLogger(event)
	Profiler.Begin("damage_logger")

	-- Random processing even when no damage event
	local processing_load = math.random(1, 5)
	local temp_calculations = {}
	for i = 1, processing_load do
		temp_calculations[i] = {
			calc = math.sin(globals.RealTime() * i) * math.cos(i),
			data = string.format("calc_%d_%.2f", i, globals.RealTime()),
		}
	end

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
			-- Store damage event with random extra data
			local event_data = {
				victim = victim:GetName(),
				damage = damage,
				health = health,
				time = globals.RealTime(),
				extra_stats = {},
			}

			-- Add random extra statistics
			for i = 1, math.random(3, 8) do
				event_data.extra_stats[i] = {
					stat = "stat_" .. i,
					value = math.random(1, 1000),
					timestamp = globals.RealTime(),
				}
			end

			table.insert(damage_events, event_data)

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

	-- Random complexity multiplier
	local complexity = math.random(1, 5)

	-- Expensive: scan for enemies
	local players = entities.FindByClass("CTFPlayer")
	local bestTarget = nil
	local bestFOV = 180
	local target_analysis = {}

	for i, player in ipairs(players) do
		if player:IsAlive() and not player:IsDormant() and player:GetTeamNumber() ~= localPlayer:GetTeamNumber() then
			-- Expensive: FOV calculation with random complexity
			local fov = math.random() * 60

			-- Random target analysis data
			local analysis = {
				player_id = i,
				fov = fov,
				distance = math.random(100, 2000),
				threat_level = math.random(1, 10),
				prediction_data = {},
			}

			-- Add random prediction calculations
			for j = 1, complexity * 3 do
				analysis.prediction_data[j] = {
					frame = j,
					x = math.random(-100, 100),
					y = math.random(-100, 100),
					confidence = math.random(),
				}
			end

			target_analysis[i] = analysis

			if fov < bestFOV then
				bestFOV = fov
				bestTarget = player
			end
		end
	end

	-- Simulate aim adjustment (expensive math with random load)
	if bestTarget then
		local iterations = math.random(50, 100)
		local result = 0
		for i = 1, iterations do
			result = result + math.sin(i * complexity) * math.cos(i / complexity)
		end

		-- Random smoothing calculations
		local smoothing_data = {}
		for i = 1, math.random(5, 15) do
			smoothing_data[i] = {
				angle = math.random() * 360,
				smooth_factor = math.random(),
				timestamp = globals.RealTime(),
			}
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

	-- Random movement complexity
	local movement_type = math.random(1, 4)
	local movement_data = {}

	-- Simulate strafe calculation (expensive)
	local velocity = localPlayer:EstimateAbsVelocity()
	if velocity then
		-- Different movement calculations based on random type
		if movement_type == 1 then -- Strafe
			for i = 1, math.random(30, 80) do
				movement_data[i] = {
					angle = math.sqrt(velocity:Length() + i),
					strafe_power = math.random() * 100,
					type = "strafe",
				}
			end
		elseif movement_type == 2 then -- Bhop
			for i = 1, math.random(20, 60) do
				movement_data[i] = {
					jump_timing = math.sin(i * 0.1) * math.cos(i * 0.05),
					ground_check = math.random() > 0.5,
					type = "bhop",
				}
			end
		elseif movement_type == 3 then -- Air strafe
			for i = 1, math.random(40, 100) do
				movement_data[i] = {
					air_accel = math.random() * 10,
					turn_rate = math.random() * 180,
					velocity_prediction = velocity:Length() * math.random(),
					type = "airstrafe",
				}
			end
		else -- Advanced movement
			for i = 1, math.random(50, 120) do
				movement_data[i] = {
					advanced_calc = math.sin(i) * math.cos(i / 2) * math.tan(i / 4),
					momentum = math.random() * 500,
					optimal_angle = math.random() * 360,
					type = "advanced",
				}
			end
		end
	end

	-- Random additional physics calculations
	local physics_load = math.random(1, 3)
	for i = 1, physics_load * 5 do
		local physics_calc = math.sqrt(i) * math.log(i + 1)
		movement_data[#movement_data + 1] = {
			physics = physics_calc,
			frame = globals.FrameCount(),
			type = "physics",
		}
	end

	Profiler.End()
end

-- Register callbacks
callbacks.Unregister("CreateMove", "profiled_createmove")
callbacks.Unregister("Draw", "profiled_draw")
callbacks.Unregister("FireGameEvent", "profiled_events")
callbacks.Unregister("Unload", "profiled_unload")

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

callbacks.Register("Unload", "profiled_unload", function()
	Profiler.BeginSystem("onunload")
	Profiler.Begin("cleanup")
	local cleanup_tasks = math.random(10, 30)
	local cleanup_data = {}
	for i = 1, cleanup_tasks do
		cleanup_data[i] = {
			task = "cleanup_task_" .. i,
			memory_freed = math.random(1000, 50000),
			status = "completed",
			timestamp = globals.RealTime(),
		}
	end
	Profiler.End()

	Profiler.Begin("shutdown")
	local shutdown_operations = math.random(5, 15)
	for i = 1, shutdown_operations do
		local operation = string.format("shutdown_%d_%x", i, math.random(100000, 999999))
	end
	Profiler.End()
	Profiler.EndSystem()
end)
