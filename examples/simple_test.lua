-- Simple Profiler Test
-- Lightweight example to test the profiler without lag

-- Load the profiler
local Profiler = require("Profiler")
Profiler.SetVisible(true)

print("✅ Simple profiler test loaded!")

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

	-- Test 30 trace lines every frame (lighter but measurable)
	for i = 1, 30 do
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

		if trace.entity ~= nil then
			traces[i] = {
				entity = trace.entity:GetClass(),
				distance = trace.fraction * 1000,
				angle = angleOffset,
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

			-- Do light math work every frame to make it measurable
			for j = 1, 10 do
				local calc = math.sin(distance + j) * math.cos(distance - j) + math.sqrt(j)
				local string_work = string.format("player_%d_calc_%d_%.6f", i, j, calc)
			end

			calculations[#calculations + 1] = {
				type = "player",
				distance = distance,
				health = entity:GetHealth(),
				processed_data = distance * 1.234567,
			}
		end
	end

	-- Process all other entities too (lighter for every frame)
	for i, building in ipairs(buildings) do
		if building:IsAlive() then
			for j = 1, 5 do
				local work = math.tan(i + j) * math.log(j + 1)
			end
		end
	end

	for i, kit in ipairs(medikits) do
		for j = 1, 3 do
			local work = math.exp(i * 0.1) + math.pow(j, 1.5)
		end
	end

	return calculations
end

local function MathWork()
	-- Light math work for every frame
	local results = {}
	for i = 1, 50 do
		local calc = 0
		for j = 1, 20 do
			calc = calc + math.sin(i * j * 0.001) * math.cos(i + j) + math.sqrt(i * j + 1)
		end
		results[i] = calc

		-- Some string work too
		local text = string.format("calc_%d_result_%.3f", i, calc)
		results[text] = calc * 2
	end
	return results
end

local function ManualTest()
	Profiler.Begin("manual_trace_work")

	-- Do the actual trace work
	local traces = PerformTraceTests()
	local entities = EntityScanning()
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

-- Register callbacks to run work every frame (lighter workload)
callbacks.Register("CreateMove", "simple_test", function(cmd)
	PerformTraceTests()
	EntityScanning()  -- Every frame now
	
	-- Manual test occasionally
	if globals.FrameCount() % 120 == 0 then
		ManualTest()
	end
end)

callbacks.Register("Draw", "simple_test", function()
	-- Simple FPS display
	draw.Color(255, 255, 255, 255)
	draw.Text(10, 10, string.format("FPS: %d | Light Work Every Frame", math.floor(1 / globals.FrameTime())))

	-- Math work every frame
	MathWork()
	
	-- More traces every frame
	PerformTraceTests()
end)

callbacks.Register("Unload", "simple_test", function()
	print("Simple test unloaded")
end)

print("Simple test ready - should see functions in profiler!")
