local Shared = require("Profiler.Shared")

local Timing = {}

local TIMING_SERVER = "http://127.0.0.1:9876"

local serverAvailable = nil
local lastFailTime = 0
local RETRY_COOLDOWN = 5

local function tryTimingServer(endpoint)
	local success, result = pcall(function()
		return http.Get(TIMING_SERVER .. endpoint)
	end)

	if success and result then
		local value = tonumber(result)
		if value and value >= 0 then
			if serverAvailable == false then
				Shared.TimingServerAvailable = true
				serverAvailable = true
			elseif serverAvailable == nil then
				serverAvailable = true
				Shared.TimingServerAvailable = true
			end
			return value
		end
	end

	return nil
end

function Timing.Now()
	if serverAvailable == false then
		local currentTime = os.clock()
		if currentTime - lastFailTime < RETRY_COOLDOWN then
			return currentTime
		end
	end

	local nanos = tryTimingServer("/now")

	if nanos then
		return nanos / 1000000000
	end

	if serverAvailable ~= false then
		serverAvailable = false
		Shared.TimingServerAvailable = false
		lastFailTime = os.clock()
	end

	return os.clock()
end

function Timing.IsServerAvailable()
	return serverAvailable == true
end

-- Smart time formatting: chooses best unit based on magnitude
-- Input: duration in seconds
-- Output: formatted string with appropriate unit
function Timing.FormatDuration(durationSeconds)
	if not durationSeconds or durationSeconds ~= durationSeconds then
		return "0ns"
	end

	local ns = durationSeconds * 1000000000

	-- Choose unit based on magnitude
	if ns < 1000 then
		-- Less than 1µs: show nanoseconds
		return string.format("%.0fns", ns)
	elseif ns < 1000000 then
		-- Less than 1ms: show microseconds
		local us = ns / 1000
		if us < 10 then
			return string.format("%.2fµs", us)
		elseif us < 100 then
			return string.format("%.1fµs", us)
		else
			return string.format("%.0fµs", us)
		end
	elseif ns < 1000000000 then
		-- Less than 1s: show milliseconds
		local ms = ns / 1000000
		if ms < 10 then
			return string.format("%.3fms", ms)
		elseif ms < 100 then
			return string.format("%.2fms", ms)
		else
			return string.format("%.1fms", ms)
		end
	else
		-- 1s or more: show seconds
		local s = ns / 1000000000
		if s < 10 then
			return string.format("%.3fs", s)
		else
			return string.format("%.2fs", s)
		end
	end
end

return Timing
