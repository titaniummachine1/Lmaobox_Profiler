--[[
    Thin HTTP client for timing_collector.exe.
    Lua never measures span duration (no os.clock, globals.RealTime, etc.).
    Only session/tick/frame/span boundaries; Go records all timestamps.
]]

local Shared = require("Profiler.Shared")
local config = require("Profiler.config")

local Collector = {}

local BASE_URL = config.collectorUrl or "http://127.0.0.1:9876"

local inApi = false
local activeCtx = nil
local spanStack = {}
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

--- IO boundary: pcall(http.Get, url) per Lmaobox policy.
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

local function closeOpenSpanStack()
	while #spanStack > 0 do
		local spanId = spanStack[#spanStack]
		table.remove(spanStack)
		httpGet("/span/end?span_id=" .. tostring(spanId))
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
end

function Collector.GetActiveContext()
	return activeCtx
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
	local sessionId = httpGet("/session/begin?script=" .. urlEncode(scriptName or "unknown"))
	local ver = httpGet("/version")
	inApi = false

	if not sessionId or sessionId == "-1" or sessionId == "" then
		Shared.CollectorAvailable = false
		collectorReachable = false
		Shared.LastError = "timing_collector not running — double-click timing_collector\\run\\timing_collector.exe ("
			.. BASE_URL
			.. ")"
		return false
	end
	if ver ~= "2" then
		Shared.CollectorAvailable = false
		Shared.LastError = "timing_collector.exe is outdated (version="
			.. tostring(ver)
			.. "). Rebuild: timing_collector\\build.bat"
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

	closeOpenSpanStack()

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

	closeOpenSpanStack()

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

	closeOpenSpanStack()

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
	if not isEnabled() or not Shared.SessionID then
		return
	end
	if not activeCtx then
		Collector.BeginTick()
	end
	if not name or name == "" then
		return
	end

	local endpoint = string.format("/span/start?name=%s&ctx=%s", urlEncode(name), urlEncode(activeCtx))
	local parentId = spanStack[#spanStack]
	if parentId then
		endpoint = endpoint .. "&parent=" .. tostring(parentId)
	end

	local idStr = httpGet(endpoint)
	local spanId = tonumber(idStr)
	if spanId and spanId > 0 then
		table.insert(spanStack, spanId)
	end
end

function Collector.End(_name)
	if not isEnabled() or not Shared.SessionID or not activeCtx then
		return
	end

	local spanId = spanStack[#spanStack]
	if not spanId then
		return
	end
	table.remove(spanStack)

	httpGet("/span/end?span_id=" .. tostring(spanId))
end

return Collector
