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
	local fps_cache = {}
	local frame_history = {}

	for i = 1, math.random(5, 25) do
		local frame_id = "frame_" .. globals.FrameCount() .. "_" .. i
		temp_data[i] = frame_id

		fps_cache[frame_id] = {
			frame_number = globals.FrameCount(),
			iteration = i,
			fps_at_time = current_fps,
			timestamp = globals.RealTime(),
			debug_info = string.format("fps_debug_%d_%.2f", i, globals.RealTime()),
		}

		frame_history[i] = {
			previous_fps = current_fps - math.random(0, 5),
			current_fps = current_fps,
			predicted_fps = current_fps + math.random(-2, 2),
			frame_delta = globals.FrameTime(),
			history_string = "fps_history_" .. tostring(i) .. "_" .. tostring(current_fps),
		}
	end

	-- Create FPS statistics
	local fps_stats = {
		min_fps = current_fps - math.random(5, 15),
		max_fps = current_fps + math.random(5, 15),
		avg_fps = current_fps + math.random(-3, 3),
		frame_count = globals.FrameCount(),
		uptime = globals.RealTime(),
		performance_level = current_fps > 60 and "high" or current_fps > 30 and "medium" or "low",
	}

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
		local calculation_cache = {}
		local result_strings = {}

		for i = 1, iterations do
			local calc_result = math.sin(i * complexity) * math.cos(i / complexity)
			calculation_cache[i] = {
				iteration = i,
				result = calc_result,
				formatted = string.format("calc_%d_%.4f", i, calc_result),
				timestamp = globals.RealTime(),
			}

			-- Create string entries that use memory
			result_strings[i] = "aim_calculation_" .. i .. "_" .. tostring(calc_result)
		end

		-- Random smoothing calculations with memory allocation
		local smoothing_data = {}
		local smoothing_history = {}
		for i = 1, math.random(5, 15) do
			local angle = math.random() * 360
			local smooth_factor = math.random()

			smoothing_data[i] = {
				angle = angle,
				smooth_factor = smooth_factor,
				timestamp = globals.RealTime(),
				debug_info = string.format("smooth_%.2f_%.4f", angle, smooth_factor),
			}

			-- Create history entries
			smoothing_history[i] = {
				previous_angle = angle - math.random(10, 30),
				current_angle = angle,
				delta = math.random(-5, 5),
				smoothed_delta = smooth_factor * math.random(-5, 5),
			}
		end

		-- Create lookup tables
		local angle_lookup = {}
		for angle = 0, 360, 5 do
			angle_lookup[angle] = {
				sin = math.sin(math.rad(angle)),
				cos = math.cos(math.rad(angle)),
				tan = math.tan(math.rad(angle)),
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

	-- Random additional physics calculations with memory allocation
	local physics_load = math.random(1, 3)
	local physics_cache = {}
	local physics_history = {}

	for i = 1, physics_load * 5 do
		local physics_calc = math.sqrt(i) * math.log(i + 1)
		local physics_id = string.format("physics_%d_%d", i, globals.FrameCount())

		physics_cache[physics_id] = {
			calculation = physics_calc,
			iteration = i,
			load_factor = physics_load,
			timestamp = globals.RealTime(),
			debug_string = string.format("phys_calc_%.4f_at_%d", physics_calc, i),
		}

		physics_history[i] = {
			previous_calc = physics_calc - math.random(),
			current_calc = physics_calc,
			delta = math.random(-0.5, 0.5),
			interpolated = physics_calc + math.random(-0.1, 0.1),
		}

		movement_data[#movement_data + 1] = {
			physics = physics_calc,
			frame = globals.FrameCount(),
			type = "physics",
			cache_id = physics_id,
			memory_debug = "physics_calculation_" .. tostring(i) .. "_" .. tostring(physics_calc),
		}
	end

	-- Create velocity prediction tables
	local velocity_predictions = {}
	for frame = 1, math.random(10, 25) do
		velocity_predictions[frame] = {
			predicted_x = math.random(-500, 500),
			predicted_y = math.random(-500, 500),
			predicted_z = math.random(-100, 100),
			confidence = math.random(),
			frame_offset = frame,
			prediction_string = string.format(
				"vel_pred_%d_%.2f_%.2f_%.2f",
				frame,
				math.random(-500, 500),
				math.random(-500, 500),
				math.random(-100, 100)
			),
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
