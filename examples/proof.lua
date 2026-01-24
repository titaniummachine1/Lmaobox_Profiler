local TIMING_SERVER = "http://127.0.0.1:9876"

local function GetNow()
	local response = http.Get(TIMING_SERVER .. "/now")
	return tonumber(response) or -1
end

local function MyFunctionToProfile()
	local result = 0
	local dummyValue = 123.456
	result = math.sqrt(dummyValue * 1.1)
end

local function ProfileExecution()
	local iterations = 10000

	local startNanos = GetNow()
	if startNanos < 0 then
		print("Timing server not responding - run timing_server.exe first!")
		return
	end

	for i = 1, iterations do
		MyFunctionToProfile()
	end

	local endNanos = GetNow()
	if endNanos < 0 then
		print("Timing server error!")
		return
	end

	local totalNanos = endNanos - startNanos
	local totalMicros = totalNanos / 1000
	local nanosPerCall = totalNanos / iterations
	local microsPerCall = totalMicros / iterations

	print(
		"Total: "
			.. totalNanos
			.. " ns ("
			.. totalMicros
			.. " µs) | Per call: "
			.. nanosPerCall
			.. " ns ("
			.. microsPerCall
			.. " µs)"
	)
end

callbacks.Unregister("Draw", "ULTIMATE_PROFILER")
callbacks.Register("Draw", "ULTIMATE_PROFILER", ProfileExecution)
