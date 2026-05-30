--[[
    Optional /now probe for diagnostics (proof.lua). Span timing is only in timing_collector.exe.
]]

local Shared = require("Profiler.Shared")
local config = require("Profiler.config")

local Timing = {}

local COLLECTOR_URL = config.collectorUrl or "http://127.0.0.1:9876"

local serverAvailable = nil
local lastFailTime = 0
local RETRY_COOLDOWN = config.httpRetryCooldown or 5

local function tryCollector(endpoint)
	local success, result = pcall(function()
		return http.Get(COLLECTOR_URL .. endpoint)
	end)

	if success and result then
		local value = tonumber(result)
		if value and value >= 0 then
			if not serverAvailable then
				serverAvailable = true
				Shared.CollectorAvailable = true
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

	local nanos = tryCollector("/now")
	if nanos then
		return nanos / 1000000000
	end

	if serverAvailable ~= false then
		serverAvailable = false
		Shared.CollectorAvailable = false
		lastFailTime = os.clock()
	end

	return os.clock()
end

function Timing.IsCollectorAvailable()
	return serverAvailable == true
end

function Timing.GetCollectorUrl()
	return COLLECTOR_URL
end

function Timing.FormatDuration(durationSeconds)
	if not durationSeconds or durationSeconds ~= durationSeconds then
		return "0ns"
	end

	local ns = durationSeconds * 1000000000

	if ns < 1000 then
		return string.format("%.0fns", ns)
	elseif ns < 1000000 then
		local us = ns / 1000
		if us < 10 then
			return string.format("%.2fµs", us)
		elseif us < 100 then
			return string.format("%.1fµs", us)
		else
			return string.format("%.0fµs", us)
		end
	elseif ns < 1000000000 then
		local ms = ns / 1000000
		if ms < 10 then
			return string.format("%.3fms", ms)
		elseif ms < 100 then
			return string.format("%.2fms", ms)
		else
			return string.format("%.1fms", ms)
		end
	else
		local s = ns / 1000000000
		if s < 10 then
			return string.format("%.3fs", s)
		else
			return string.format("%.2fs", s)
		end
	end
end

return Timing
