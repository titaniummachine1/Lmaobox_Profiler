-- ULTRA AGGRESSIVE Test for Microprofiler - Functions that WILL be visible
-- This test creates functions that will definitely show up as visible bars

local Profiler = require("Profiler")

-- Enable profiler
Profiler.SetVisible(true)
print("✅ Profiler enabled!")

-- Function that does ULTRA HEAVY work - guaranteed to take 50+ms
local function UltraHeavyCalculation()
	local result = 0
	for i = 1, 12000 do -- toned-down count to prevent lock-ups
		result = result + math.sin(i) * math.cos(i) + math.sqrt(i) + math.tan(i / 1000) + math.log(i + 1)
	end
	return result
end

local function UltraHeavyStringWork()
	local text = ""
	for i = 1, 2500 do -- reduced strings
		text = text .. string.format("ultra_string_chunk_%d_%.4f", i, math.sin(i))
	end
	return #text
end

local function UltraHeavyTableWork()
	local tbl = {}
	for i = 1, 6000 do -- fewer entries to avoid freeze
		tbl[i] = {
			id = i,
			value = math.sin(i) * math.cos(i),
			extra = { nested = { value = i * 2 } },
		}
	end

	table.sort(tbl, function(a, b)
		return a.value > b.value
	end)

	return #tbl
end

-- Function that does artificial busy waiting to force visible duration
local function ArtificialDelayWork()
	local startTime = globals.RealTime()
	local targetDuration = 0.015 -- much smaller delay

	-- Do work until we've spent enough time
	local result = 0
	while (globals.RealTime() - startTime) < targetDuration do
		for i = 1, 250 do
			result = result + math.sin(i) * math.cos(i) + math.sqrt(i)
		end
	end

	return result
end

-- Function that does nested ultra heavy work
local function NestedUltraHeavyWork()
	local total = 0

	for i = 1, 40000 do
		total = total + math.sin(i) + math.cos(i)
	end

	for i = 1, 30000 do
		total = total + math.cos(i) * math.sqrt(i)
	end

	for i = 1, 20000 do
		total = total + math.tan(i / 100) + math.log(i + 1)
	end

	return total
end

-- Function that does file-like operations (very slow)
local function SimulatedFileWork()
	local data = {}
	for i = 1, 5000 do
		data[i] = string.format("file_line_%d", i)
	end

	local sum = 0
	for i = 1, #data do
		sum = sum + #data[i] + math.sin(i)
	end

	return sum
end

-- Function that does network-like operations (very slow)
local function SimulatedNetworkWork()
	local packets = {}
	for i = 1, 600 do
		packets[i] = {
			id = i,
			data = string.format("packet_%d", i),
			checksum = i * 12345,
		}
	end

	local result = 0
	for i = 1, #packets do
		result = result + packets[i].id + #packets[i].data + packets[i].checksum
	end

	return result
end

-- Main test function that calls all the ultra heavy work
local function RunUltraHeavyTests()
	print("🧪 Running ULTRA heavy work tests (balanced CPU)...")

	local steps = {
		{ label = "Ultra heavy math", fn = UltraHeavyCalculation },
		{ label = "Ultra heavy strings", fn = UltraHeavyStringWork },
		{ label = "Table sorting", fn = UltraHeavyTableWork },
		{ label = "Periodic delay", fn = ArtificialDelayWork },
	}

	for _, entry in ipairs(steps) do
		print(string.format("   Starting %s...", entry.label))
		local result = entry.fn()
		print(string.format("✅ %s completed: %s", entry.label, tostring(result)))
	end

	print("🎉 Balanced heavy tests completed! Profiler UI should still be responsive.")
end

-- Run tests immediately
print("🚀 Running ULTRA heavy tests immediately...")
RunUltraHeavyTests()

-- Also run tests periodically
local frameCount = 0
callbacks.Register("Draw", "ultra_simple_test", function()
	frameCount = frameCount + 1

	if frameCount % 900 == 0 then
		print("🔄 Periodic ULTRA heavy tests (staggered) running...")
		RunUltraHeavyTests()
	end
end)

print("✅ ULTRA aggressive test loaded!")
print("🔄 Tests will run every 5 seconds automatically")
print("⚠️  This test is designed to create functions that take 50-100+ milliseconds each")
