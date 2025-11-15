-- Lmaobox Microprofiler Example
-- Save as example.lua in %localappdata%
-- Load with: lua_load example.lua
--
-- This example demonstrates:
-- 1. Automatic function profiling (no manual hooks needed!)
-- 2. One manual profiling example for custom threads
-- 3. Clean, readable code that shows performance characteristics

local function ensureProfilerReload()
	local existingProfiler = package.loaded["Profiler"]
	if existingProfiler and existingProfiler.Unload then
		print("🔄 Detected existing Profiler instance - unloading before reload...")
		existingProfiler.Unload()
	end
	package.loaded["Profiler"] = nil
end

-- RELOAD SUPPORT: Improved package unloading pattern
if MICROPROFILER_DEMO_LOADED then
	print("🔄 Microprofiler demo already loaded - reloading for fresh updates...")

	-- Unregister existing callbacks first
	if callbacks then
		callbacks.Unregister("CreateMove", "microprofiler_demo")
		callbacks.Unregister("Draw", "microprofiler_demo")
		callbacks.Unregister("FireGameEvent", "microprofiler_demo")
		callbacks.Unregister("Unload", "microprofiler_demo")
	end

	-- Clear demo flag to allow reload
	MICROPROFILER_DEMO_LOADED = false
	print("   ✓ Demo callbacks cleared")
end

ensureProfilerReload()
local scriptFullPath = GetScriptName()
local scriptFileName = scriptFullPath:match("\\([^\\]-)$"):gsub("%.lua$", "") or "example"
print(string.format("📜 Loading script: %s (from %s)", scriptFileName, scriptFullPath))

-- Load the Microprofiler system (will auto-reload if needed)
local Profiler = require("Profiler")

-- Mark demo as loaded
MICROPROFILER_DEMO_LOADED = true

-- Suppress linter warnings for external APIs
---@diagnostic disable: undefined-global

-- IMPORTANT: Check if profiler is already visible to avoid double-enabling
if not Profiler.SetVisible then
	print("❌ ERROR: Profiler not loaded correctly!")
	return
end

-- Just enable the profiler - no need to check microprofiler directly
Profiler.SetVisible(true)
print("✅ Profiler enabled!")

print("✅ Microprofiler enabled! All functions are automatically profiled.")
print("Controls: P = Pause/Resume, O = Show/Hide detailed view")
print("Features: Automatic timeline + Custom profiling threads")
print("Click frame pillars to inspect timing, drag to pan, scroll to zoom!")

-- TEST: Heavy work that should be easily visible
local function TestManualProfiling()
	Profiler.Begin("HEAVY_MANUAL_WORK")

	-- MUCH more significant work to ensure it shows up
	for i = 1, 5000 do -- Increased from 1000
		local result = math.sin(i) * math.cos(i) + math.sqrt(i) + math.tan(i / 100)
		local text = string.format("heavy_test_%d_%.6f", i, result)
		-- Create significant memory allocation
		local data = {
			index = i,
			value = result,
			text = text,
			timestamp = globals.RealTime(),
			extra_data = {
				computed = result * 2,
				formatted = text .. "_extra",
				nested = { level = i % 10, category = "test" },
			},
		}
		-- Force string operations
		local combined = data.text .. data.extra_data.formatted
	end

	Profiler.End()
end

-- Call test function immediately and repeatedly
TestManualProfiling()
print("🧪 Manual profiling test completed")

-- Nested function hierarchy for testing profiler display
local function InnerCalculation(value)
	-- Deepest level function
	local result = 0
	for i = 1, 50 do
		result = result + math.sin(value + i) * math.cos(value - i)
	end
	return result
end

local function MiddleProcessor(data)
	-- Mid-level function that calls InnerCalculation
	local processed = {}
	for i = 1, #data do
		processed[i] = InnerCalculation(data[i]) + data[i] * 2
	end
	return processed
end

local function TopLevelWork()
	-- Top-level function that orchestrates the work
	local inputData = {}
	for i = 1, 100 do
		inputData[i] = i * 0.1
	end

	local result = MiddleProcessor(inputData)

	-- Additional work at top level
	local sum = 0
	for i = 1, #result do
		sum = sum + result[i]
	end

	return sum
end

local function ContinuousWork()
	-- Call the nested hierarchy
	local hierarchyResult = TopLevelWork()

	-- Additional work in this function
	local total = 0
	for i = 1, 100 do
		total = total + math.sin(i * 0.1) * math.cos(i * 0.2) + hierarchyResult / 1000
		local temp = string.format("calc_%d_%.3f", i, total)
	end
	return total
end

local function StringManipulation(text)
	-- Helper for MoreWork
	local modified = ""
	for i = 1, 20 do
		modified = modified .. text .. "_" .. tostring(i)
	end
	return modified
end

local function MoreWork()
	-- Calls StringManipulation
	local result = ""
	for i = 1, 50 do
		local base = string.format("item_%d", i)
		result = result .. StringManipulation(base)
		local temp = { id = i, value = result, computed = i * 2 }
	end
	return result
end

local function SortingAlgorithm(table_to_sort)
	-- Helper for ExpensiveTableWork
	table.sort(table_to_sort, function(a, b)
		return a.id > b.id
	end)
	return table_to_sort
end

local function ExpensiveTableWork()
	-- Creates table then calls SortingAlgorithm
	local bigTable = {}
	for i = 1, 300 do
		bigTable[i] = {
			id = i,
			data = string.format("entry_%d", i),
			nested = { value = i * 2, flag = i % 2 == 0 },
		}
	end

	local sorted = SortingAlgorithm(bigTable)
	return #sorted
end

-- Create fonts for our example
local consolas = draw.CreateFont("Consolas", 17, 500)
local verdana = draw.CreateFont("Verdana", 16, 800)

-- Variables for our examples
local current_fps = 0
local damage_events = {}

-- Example 1: Simple FPS Counter (automatically profiled)
local function SimpleFPSCounter()
	draw.SetFont(consolas)
	draw.Color(255, 255, 255, 255)

	-- Update fps every 100 frames
	if globals.FrameCount() % 100 == 0 then
		current_fps = math.floor(1 / globals.FrameTime())
	end

	-- Some memory allocation for realistic profiling data (shows in profiler)
	local _ = {
		current = current_fps,
		frame = globals.FrameCount(),
		time = globals.RealTime(),
		delta = globals.FrameTime(),
	}

	draw.Text(5, 5, string.format("[FPS: %d | Microprofiler: ON | Frame: %d]", current_fps, globals.FrameCount()))
end

-- Example 2: Player ESP (automatically profiled)
local function SimplePlayerESP()
	if engine.Con_IsVisible() or engine.IsGameUIVisible() then
		return
	end

	-- This function call will be automatically profiled
	local players = entities.FindByClass("CTFPlayer")

	-- Process players
	for i, player in ipairs(players) do
		if player:IsAlive() and not player:IsDormant() then
			local screenPos = client.WorldToScreen(player:GetAbsOrigin())
			if screenPos then
				draw.SetFont(verdana)
				draw.Color(255, 255, 255, 255)
				draw.Text(screenPos[1], screenPos[2], player:GetName())
			end
		end
	end
end

-- Example 3: Simplified Aimbot Logic (automatically profiled)
local function SimplifiedAimbotLogic(cmd)
	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer or not localPlayer:IsAlive() then
		return
	end

	-- Simplified computation - less memory intensive
	local players = entities.FindByClass("CTFPlayer")
	local bestTarget = nil
	local bestFOV = 180

	-- Simplified calculations
	for i, player in ipairs(players) do
		if player:IsAlive() and not player:IsDormant() and player:GetTeamNumber() ~= localPlayer:GetTeamNumber() then
			-- Simple FOV calculation
			local fov = math.random() * 60

			-- Minimal math for demonstration
			local _ = math.sin(fov) * math.cos(fov / 2)

			if fov < bestFOV then
				bestFOV = fov
				bestTarget = player
			end
		end
	end

	-- Simple aim adjustment simulation
	if bestTarget then
		local angle = math.sin(globals.RealTime()) * 0.1
		local _ = math.cos(angle) -- Simple calculation
	end
end

-- Example 4: Simplified Manual Profiling API Test
local function ManualProfilingExample()
	-- This is the ONE manual profiling example to test the API
	Profiler.Begin("custom_operation")

	-- Simplified custom operation - less memory intensive
	local work_size = math.random(10, 50) -- Much smaller
	local total = 0

	for i = 1, work_size do
		-- Simple calculations without storing results
		total = total + math.sqrt(i) * math.sin(i / 10)
	end

	-- Nested custom profiling
	Profiler.Begin("custom_processing")
	for i = 1, 10 do -- Much smaller loop
		local _ = string.format("proc_%d_%.2f", i, globals.RealTime())
	end
	Profiler.End()

	-- Simple operation
	Profiler.Begin("custom_math")
	local result = math.sin(total) * math.cos(globals.RealTime())
	local _ = result -- Use the result
	Profiler.End()

	Profiler.End()
end

-- Example 5: Event Handler (automatically profiled)
local function DamageEventHandler(event)
	if event:GetName() ~= "player_hurt" then
		return
	end

	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer then
		return
	end

	-- These function calls are automatically profiled
	local victim = entities.GetByUserID(event:GetInt("userid"))
	local attacker = entities.GetByUserID(event:GetInt("attacker"))

	if attacker and localPlayer:GetIndex() == attacker:GetIndex() then
		local damage = event:GetInt("damageamount")
		local health = event:GetInt("health")

		-- Store damage data (with some processing)
		local damage_data = {
			victim_name = victim:GetName(),
			damage = damage,
			health = health,
			timestamp = globals.RealTime(),
			frame = globals.FrameCount(),
		}

		table.insert(damage_events, damage_data)

		-- Keep only recent events
		if #damage_events > 10 then
			table.remove(damage_events, 1)
		end

		print(string.format("Hit %s for %d damage (health: %d)", victim:GetName(), damage, health))
	end
end

-- Movement Helper (automatically profiled, simplified)
local function MovementHelper(cmd)
	local localPlayer = entities.GetLocalPlayer()
	if not localPlayer then
		return
	end

	-- Simplified velocity calculations
	local velocity = localPlayer:EstimateAbsVelocity()
	if velocity then
		local vel_length = velocity:Length()

		-- Simple movement calculations without storing results
		local calc_count = math.random(5, 15) -- Much smaller

		for i = 1, calc_count do
			-- Simple calculations without memory allocation
			local strafe_angle = math.atan(vel_length / math.max(i, 0.001))
			local acceleration = math.sqrt(vel_length + i)
			local _ = math.sin(i * 0.1) * vel_length + strafe_angle + acceleration
		end
	end
end

-- Register callbacks (functions will be automatically profiled!)
callbacks.Unregister("CreateMove", "microprofiler_demo")
callbacks.Unregister("Draw", "microprofiler_demo")
callbacks.Unregister("FireGameEvent", "microprofiler_demo")
callbacks.Unregister("Unload", "microprofiler_demo")

-- CreateMove callback
callbacks.Register("CreateMove", "microprofiler_demo", function(cmd)
	-- All these function calls are automatically profiled!
	SimplifiedAimbotLogic(cmd)
	MovementHelper(cmd)
	ManualProfilingExample() -- Only manual profiling example

	-- Add our continuous work functions EVERY FRAME
	ContinuousWork()
	MoreWork()
	ExpensiveTableWork() -- NEW heavy function

	-- Add some random manual profiling every 30 frames (more frequent)
	if globals.FrameCount() % 30 == 0 then
		TestManualProfiling()
	end

	-- Even more frequent manual profiling with different names
	if globals.FrameCount() % 45 == 0 then
		Profiler.Begin("CREATEMOCE_HEAVY_CALC")
		for i = 1, 100 do
			local calc = math.sin(i) + math.cos(i) + math.sqrt(i)
		end
		Profiler.End()
	end
end)

-- Draw callback
callbacks.Register("Draw", "microprofiler_demo", function()
	-- All these function calls are automatically profiled!
	SimpleFPSCounter()
	SimplePlayerESP()

	-- Add heavy work EVERY draw frame
	ContinuousWork()
	MoreWork()

	-- Manual profiling in Draw callback too
	if globals.FrameCount() % 20 == 0 then
		Profiler.Begin("DRAW_HEAVY_WORK")
		ExpensiveTableWork()
		for i = 1, 50 do
			local text = string.format("draw_calc_%d", i)
			local data = { frame = globals.FrameCount(), text = text }
		end
		Profiler.End()
	end

	-- DON'T call Profiler.Draw() here - let the main profiler handle it
	-- This prevents double drawing
	-- Profiler.Draw()
end)

-- Event callback
callbacks.Register("FireGameEvent", "microprofiler_demo", function(event)
	-- This function call is automatically profiled!
	DamageEventHandler(event)
end)

-- Cleanup callback
callbacks.Register("Unload", "microprofiler_demo", function()
	-- Clean shutdown
	print("🔄 Microprofiler demo unloading...")

	-- Manual profiling for cleanup operations
	Profiler.Begin("cleanup_operations")

	local cleanup_tasks = {
		"callbacks_cleanup",
		"memory_cleanup",
		"state_reset",
		"profiler_shutdown",
	}

	for i, task in ipairs(cleanup_tasks) do
		-- Simulate cleanup work
		local task_data = string.format("cleanup_%s_%d", task, globals.FrameCount())
		local task_result = math.random(1000, 5000) -- Simulate memory freed
	end

	Profiler.End()

	-- Clear demo loaded flag to allow reload
	MICROPROFILER_DEMO_LOADED = false

	print("✅ Microprofiler demo unloaded cleanly!")
end)

print("🚀 Microprofiler demo loaded!")
print("💡 Notice: Most functions are automatically profiled now!")
print("📊 Check the profiler UI - you should see detailed timing for all functions")
print("🔧 Only 'custom_expensive_operation' uses manual profiling as an API demo")
print("")
print("🔄 RELOAD TESTING:")
print("   • Run 'lua_load example.lua' again to test auto-reload")
print("   • Or call 'Profiler.Reload()' to manually reload profiler")
print("   • All packages will be cleared and reloaded fresh!")
