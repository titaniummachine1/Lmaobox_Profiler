local Shared = require("Profiler.Shared")

local Timing = {}

local TIMING_SERVER = "http://127.0.0.1:9876"

local serverAvailable = nil
local lastFailTime = 0
local RETRY_COOLDOWN = 5
local nextTimerId = 1

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

local function generateTimerId()
	local id = nextTimerId
	nextTimerId = nextTimerId + 1
	return tostring(id)
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

return Timing
