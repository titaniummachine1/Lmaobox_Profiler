--[[
    HTTP client for Go timing_collector (all requests via http.Get).
]]

local Shared = require("Profiler.Shared")
local config = require("Profiler.config")

local Collector = {}

local BASE_URL = config.collectorUrl or "http://127.0.0.1:9876"

local inApi = false
local activeCtx = nil -- "tick" | "frame" | nil
local spanStack = {}
local enabled = config.enabled ~= false

local function urlEncode(str)
	if not str then
		return ""
	end
	return (str:gsub("([^%w%-%.%_%~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function httpGet(endpoint)
	if not http or not http.Get then
		return nil
	end
	local ok, result = pcall(function()
		return http.Get(BASE_URL .. endpoint)
	end)
	if ok and result and result ~= "" then
		return result
	end
	return nil
end

local function isEnabled()
	return enabled and Shared.Enabled ~= false
end

function Collector.SetEnabled(value)
	enabled = value ~= false
	Shared.Enabled = enabled
end

function Collector.IsEnabled()
	return isEnabled()
end

function Collector.IsCollectorReachable()
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
	if not isEnabled() then
		return false
	end
	if inApi then
		return false
	end

	inApi = true
	local endpoint = "/session/begin?script=" .. urlEncode(scriptName or "unknown")
	local sessionId = httpGet(endpoint)
	inApi = false

	if sessionId and sessionId ~= "-1" and sessionId ~= "" then
		Shared.SessionID = sessionId
		Shared.ActiveScriptName = scriptName
		Shared.CollectorAvailable = true
		Collector.ResetLocalStack()
		return true
	end

	Shared.CollectorAvailable = false
	return false
end

function Collector.EndSession()
	if not Shared.SessionID then
		Collector.ResetLocalStack()
		return
	end

	if inApi then
		return
	end

	inApi = true
	httpGet("/session/end")
	inApi = false

	Shared.SessionID = nil
	Collector.ResetLocalStack()
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
	if not name or name == "" or inApi then
		return
	end

	local parent = spanStack[#spanStack]
	local parentParam = ""
	if parent then
		parentParam = "&parent=" .. tostring(parent)
	end

	inApi = true
	local endpoint = "/span/start?name=" .. urlEncode(name) .. "&ctx=" .. urlEncode(activeCtx) .. parentParam
	local spanId = httpGet(endpoint)
	inApi = false

	local id = tonumber(spanId)
	if id and id > 0 then
		table.insert(spanStack, id)
	end
end

function Collector.End(name)
	if not isEnabled() or not Shared.SessionID or not activeCtx then
		return
	end
	if inApi then
		return
	end

	local spanId = spanStack[#spanStack]
	if not spanId then
		return
	end

	table.remove(spanStack)

	inApi = true
	httpGet("/span/end?span_id=" .. tostring(spanId))
	inApi = false
end

return Collector
