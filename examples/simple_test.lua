-- Simple Profiler Test
-- Lightweight example to test the profiler without lag

-- Load the profiler
local Profiler = require("Profiler")
Profiler.SetVisible(true)
-- Don't pause immediately - let it collect data first

print("✅ Simple profiler test loaded!")
-- Check all status after a delay to ensure profiler is fully initialized
callbacks.Register("CreateMove", "check_status", function(cmd)
	if globals.FrameCount() == 5 then
		print("🔧 Profiler visible:", Profiler.IsVisible())
		print("🔧 Profiler paused:", Profiler.IsPaused())
		print("🔧 Body visible:", Profiler.IsBodyVisible())
		Profiler.SetBodyVisible(true)
		print("🔧 Body set to visible")
		callbacks.Unregister("CreateMove", "check_status")
	end
end)

-- Simple test function that should be easily detected (reduced for every-frame)
local function SimpleTestFunction()
	local result = 0
	for i = 1, 200 do
		result = result + math.sin(i) * math.cos(i) + math.sqrt(i)
	end
	return result
end

-- Useful trace testing functions with more work to be measurable
local function PerformTraceTests()
	local me = entities.GetLocalPlayer()
	if not me then
		return
	end

	local source = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
	local viewAngles = engine.GetViewAngles()
	local forward = viewAngles:Forward()

	local traces = {}

	-- Test 100 trace lines with heavy math work
	for i = 1, 10 do
		-- Vary the direction slightly for each trace
		local angleOffset = (i - 25) * 2 -- -48 to +48 degrees spread
		local yawOffset = math.rad(angleOffset)

		-- Calculate direction with offset
		local cos_yaw = math.cos(viewAngles.yaw + yawOffset)
		local sin_yaw = math.sin(viewAngles.yaw + yawOffset)
		local cos_pitch = math.cos(math.rad(viewAngles.pitch))

		local direction = Vector3(cos_yaw * cos_pitch, sin_yaw * cos_pitch, -math.sin(math.rad(viewAngles.pitch)))

		local destination = source + direction * 1000
		local trace = engine.TraceLine(source, destination, MASK_SHOT_HULL)

		-- Medium math work (reduced since running every frame from 2 callbacks)
		local result = 0
		for j = 1, 100 do
			result = result + math.sin(angleOffset + j * 0.1) * math.cos(angleOffset - j * 0.1) + math.sqrt(j)
			local heavy = math.tan(j * 0.01) + math.log(j + 1)
			result = result + heavy
		end

		if trace.entity ~= nil then
			traces[i] = {
				entity = trace.entity:GetClass(),
				distance = trace.fraction * 1000,
				angle = angleOffset,
				heavy_result = result, -- Store the work result
			}
		end
	end

	return traces
end

local function EntityScanning()
	-- Scan for entities and do heavy calculations
	local players = entities.FindByClass("CTFPlayer")
	local buildings = entities.FindByClass("CObjectSentrygun")
	local medikits = entities.FindByClass("CHealthKit")
	local ammo = entities.FindByClass("CAmmoBox")

	local calculations = {}

	-- More intensive calculations for each player
	for i, entity in ipairs(players) do
		if entity:IsAlive() and not entity:IsDormant() then
			local origin = entity:GetAbsOrigin()
			local distance = origin:Length()

			-- Do heavy math work to make it measurable
			for j = 1, 50 do
				local calc = math.sin(distance + j) * math.cos(distance - j) + math.sqrt(j)
				local heavy = math.tan(j * 0.01) + math.log(j + 1) + math.exp(j * 0.001)
				local string_work = string.format("player_%d_calc_%d_%.6f_%.6f", i, j, calc, heavy)
			end

			calculations[#calculations + 1] = {
				type = "player",
				distance = distance,
				health = entity:GetHealth(),
				processed_data = distance * 1.234567,
			}
		end
	end

	-- Process all other entities too (heavy work)
	for i, building in ipairs(buildings) do
		if building:IsAlive() then
			for j = 1, 20 do
				local work = math.tan(i + j) * math.log(j + 1) + math.sin(j * 0.1)
			end
		end
	end

	for i, kit in ipairs(medikits) do
		for j = 1, 10 do
			local work = math.exp(i * 0.1) + math.pow(j, 1.5) + math.cos(j * 0.1)
		end
	end

	return calculations
end

local function MathWork()
	-- Heavy math work for measurable duration
	local results = {}
	for i = 1, 20 do
		local calc = 0
		for j = 1, 10 do
			calc = calc + math.sin(i * j * 0.001) * math.cos(i + j) + math.sqrt(i * j + 1)
			calc = calc + math.tan(i * 0.01) + math.log(j + 1) + math.exp(i * 0.001)
		end
		results[i] = calc

		-- Heavy string work too
		for k = 1, 5 do
			local text = string.format("calc_%d_%d_result_%.6f_heavy_%.6f", i, k, calc, calc * k)
			results[text] = calc * k
		end
	end
	return results
end

local function ManualTest()
	Profiler.Begin("manual_trace_work")

	-- Do the actual trace work with forced delays
	local traces = PerformTraceTests()

	-- Forced delay between operations
	local delay_start = globals.RealTime()
	while (globals.RealTime() - delay_start) < 0.001 do
		-- Busy wait for 1ms
	end

	local entities = EntityScanning()

	-- Another forced delay
	delay_start = globals.RealTime()
	while (globals.RealTime() - delay_start) < 0.002 do
		-- Busy wait for 2ms
	end

	local math_results = MathWork()

	-- Process results
	local hitCount = 0
	for i, trace in pairs(traces) do
		if trace then
			hitCount = hitCount + 1
		end
	end

	Profiler.End()
	return hitCount, #entities, #math_results
end

-- Register callbacks to run work EVERY SINGLE FRAME
callbacks.Register("CreateMove", "simple_test", function(cmd)
	-- Debug print occasionally to confirm it's running
	if globals.FrameCount() % 60 == 0 then
		print("🎯 CreateMove callback running - Frame:", globals.FrameCount())
	end

	-- Auto-pause after 3 seconds to show collected data
	if globals.FrameCount() == 180 and not Profiler.IsPaused() then
		print("🎯 Auto-pausing to show collected data...")
		Profiler.TogglePause()
	end

	-- Call functions EVERY FRAME for continuous profiling
	SimpleTestFunction()
	PerformTraceTests()
	EntityScanning()

	-- Manual test occasionally (but still every frame work above)
	if globals.FrameCount() % 120 == 0 then
		print("🎯 Running ManualTest() - Frame:", globals.FrameCount())
		ManualTest()
	end
end)

callbacks.Register("Draw", "simple_test", function()
	-- Simple FPS display
	draw.Color(255, 255, 255, 255)
	draw.Text(10, 10, string.format("FPS: %d | Heavy Work EVERY Frame", math.floor(1 / globals.FrameTime())))

	-- Heavy work EVERY SINGLE FRAME in Draw callback too
	MathWork()
	PerformTraceTests()
	SimpleTestFunction() -- Also call here for even more frequent execution
end)

callbacks.Register("Unload", "simple_test", function()
	print("Simple test unloaded")
end)

print("Simple test ready - should see functions in profiler!")
