--[[
    HTTP client for Go timing_collector.
    Spans recorded locally; HTTP flushed at EndTick/EndFrame only.
    Lmaobox: pcall only on http.Get (IO). No pcall around engine/draw/callbacks.
    Prefer http.GetAsync when available to avoid blocking the game.
]]

local Shared = require("Profiler.Shared")
local config = require("Profiler.config")

local Collector = {}

local BASE_URL = config.collectorUrl or "http://127.0.0.1:9876"

local inApi = false
local activeCtx = nil
local spanStack = {}
local localSpans = {}
local enabled = config.enabled ~= false
local collectorReachable = nil

local function urlEncode(str)
	if not str then
		return ""
	end
	return (str:gsub("([^%w%-%.%_%~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

--- IO boundary: pcall(http.Get, url) per Lmaobox pcall policy (not pcall(function() http.Get() end)).
local function httpGet(endpoint)
	if not http or not http.Get then
		return nil
	end
	local ok, result = pcall(http.Get, BASE_URL .. endpoint)
	if ok and result and result ~= "" then
		collectorReachable = true
		return result
	end
	collectorReachable = false
	return nil
end

local function isEnabled()
	return enabled and Shared.Enabled ~= false
end

local function buildStackName(spanIdx)
	local parts = {}
	local idx = spanIdx
	local depth = 0
	while idx and localSpans[idx] and depth < 32 do
		table.insert(parts, 1, localSpans[idx].name)
		idx = localSpans[idx].parentIdx
		depth = depth + 1
	end
	if #parts == 0 then
		return ""
	end
	return table.concat(parts, ";")
end

local function flushLocalSpans(ctx)
	if not isEnabled() or not Shared.SessionID then
		return
	end
	if inApi then
		return
	end

	inApi = true
	for i = 1, #localSpans do
		local s = localSpans[i]
		if s and s.ctx == ctx and s.closed and not s.sent then
			local durNs = math.floor((s.endClock - s.startClock) * 1000000000)
			if durNs < 0 then
				durNs = 0
			end
			local stack = buildStackName(i)
			local endpoint = string.format(
				"/span/report?name=%s&ctx=%s&dur_ns=%d&stack=%s",
				urlEncode(s.name),
				urlEncode(ctx),
				durNs,
				urlEncode(stack)
			)
			local result = httpGet(endpoint)
			if result == "0" then
				s.sent = true
			end
		end
	end
	inApi = false

	local kept = {}
	for i = 1, #localSpans do
		local s = localSpans[i]
		if s and not s.sent then
			kept[#kept + 1] = s
		end
	end
	localSpans = kept
end

local function closeOpenLocalSpans()
	for i = 1, #localSpans do
		local s = localSpans[i]
		if s and not s.closed then
			s.endClock = os.clock()
			s.closed = true
		end
	end
end

function Collector.SetEnabled(value)
	enabled = value ~= false
	Shared.Enabled = enabled
end

function Collector.IsEnabled()
	return isEnabled()
end

function Collector.IsCollectorReachable()
	if collectorReachable ~= nil then
		return collectorReachable
	end
	local r = httpGet("/now")
	return r ~= nil and tonumber(r) ~= nil
end

function Collector.ResetLocalStack()
	activeCtx = nil
	spanStack = {}
	localSpans = {}
end

function Collector.GetActiveContext()
	return activeCtx
end

local function countUnsentSpans()
	local n = 0
	for i = 1, #localSpans do
		local s = localSpans[i]
		if s and s.closed and not s.sent then
			n = n + 1
		end
	end
	return n
end

function Collector.BeginSession(scriptName)
	Shared.LastError = nil
	if not isEnabled() then
		Shared.LastError = "Profiler is disabled (SetEnabled(false))"
		return false
	end
	if inApi then
		Shared.LastError = "Profiler HTTP call already in progress"
		return false
	end
	if not http or not http.Get then
		Shared.LastError = "Lmaobox http.Get is not available"
		return false
	end

	inApi = true
	local endpoint = "/session/begin?script=" .. urlEncode(scriptName or "unknown")
	local sessionId = httpGet(endpoint)
	local ver = httpGet("/version")
	inApi = false

	if not sessionId or sessionId == "-1" or sessionId == "" then
		Shared.CollectorAvailable = false
		collectorReachable = false
		Shared.LastError = "timing_collector not running — start timing_collector\\run_collector.bat (" .. BASE_URL .. ")"
		return false
	end
	if ver ~= "2" then
		Shared.CollectorAvailable = false
		Shared.LastError = "timing_collector.exe is outdated (version=" .. tostring(ver) .. "). Run run_collector.bat to rebuild."
		httpGet("/session/end")
		return false
	end

	Shared.SessionID = sessionId
	Shared.ActiveScriptName = scriptName
	Shared.CollectorAvailable = true
	collectorReachable = true
	Collector.ResetLocalStack()
	return true
end

function Collector.EndSession()
	if Shared.SessionEnding then
		return false, Shared.LastError or "session end already in progress"
	end
	if not Shared.SessionID then
		Collector.ResetLocalStack()
		return true
	end

	Shared.SessionEnding = true
	Shared.LastError = nil

	closeOpenLocalSpans()
	flushLocalSpans("tick")
	flushLocalSpans("frame")

	local unsent = countUnsentSpans()
	if unsent > 0 then
		Shared.LastError = string.format(
			"%d span(s) were not accepted by timing_collector. Rebuild timing_collector.exe (run_collector.bat).",
			unsent
		)
		Shared.SessionEnding = false
		return false, Shared.LastError
	end

	if activeCtx == "tick" then
		httpGet("/tick/end")
	elseif activeCtx == "frame" then
		httpGet("/frame/end")
	end

	local sessionId = Shared.SessionID
	local result = httpGet("/session/end")

	Shared.SessionID = nil
	Shared.ActiveScriptName = nil
	activeCtx = nil
	Shared.SessionEnding = false
	Collector.ResetLocalStack()

	if result == "OK" then
		Shared.LastExportSessionID = sessionId
		return true, sessionId
	end
	if result and result:sub(1, 4) == "ERR:" then
		Shared.LastError = result:sub(5)
		return false, Shared.LastError
	end
	Shared.LastError = "timing_collector did not respond on " .. BASE_URL
	return false, Shared.LastError
end

function Collector.BeginTick()
	if not isEnabled() or not Shared.SessionID then
		return
	end
	if inApi then
		return
	end

	inApi = true
	httpGet("/tick/begin")
	inApi = false

	activeCtx = "tick"
	spanStack = {}
end

function Collector.EndTick()
	if not isEnabled() or not Shared.SessionID then
		return
	end

	flushLocalSpans("tick")

	if inApi then
		return
	end
	inApi = true
	httpGet("/tick/end")
	inApi = false

	if activeCtx == "tick" then
		activeCtx = nil
	end
	spanStack = {}
end

function Collector.BeginFrame()
	if not isEnabled() or not Shared.SessionID then
		return
	end
	if inApi then
		return
	end

	inApi = true
	httpGet("/frame/begin")
	inApi = false

	activeCtx = "frame"
	spanStack = {}
end

function Collector.EndFrame()
	if not isEnabled() or not Shared.SessionID then
		return
	end

	flushLocalSpans("frame")

	if inApi then
		return
	end
	inApi = true
	httpGet("/frame/end")
	inApi = false

	if activeCtx == "frame" then
		activeCtx = nil
	end
	spanStack = {}
end

function Collector.Begin(name)
	if not isEnabled() or not Shared.SessionID or not activeCtx then
		return
	end
	if not name or name == "" then
		return
	end

	local idx = #localSpans + 1
	localSpans[idx] = {
		name = name,
		ctx = activeCtx,
		parentIdx = spanStack[#spanStack],
		startClock = os.clock(),
		endClock = nil,
		closed = false,
		sent = false,
	}
	table.insert(spanStack, idx)
end

function Collector.End(_name)
	if not isEnabled() or not Shared.SessionID or not activeCtx then
		return
	end

	local idx = spanStack[#spanStack]
	if not idx then
		return
	end
	table.remove(spanStack)

	local s = localSpans[idx]
	if s and not s.closed then
		s.endClock = os.clock()
		s.closed = true
	end
end

return Collector
