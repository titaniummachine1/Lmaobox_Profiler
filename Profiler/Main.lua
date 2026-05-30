--[[
    Profiler — thin Lua client for Go timing_collector.
]]

do
	local stale = package.loaded["Profiler"]
	if type(stale) == "table" and type(stale.SetEnabled) ~= "function" then
		for _, pkg in ipairs({
			"Profiler",
			"Profiler.collector",
			"Profiler.timing",
			"Profiler.Shared",
			"Profiler.config",
			"Profiler.Main",
		}) do
			package.loaded[pkg] = nil
		end
	end
end

local Shared = require("Profiler.Shared")
local Collector = require("Profiler.collector")

local INVALID_SCRIPT_PATTERN = "%[C%]"

local function isValidScriptName(name)
	if not name or name == "" then
		return false
	end
	if name == "Profiler" or name == "unknown" then
		return false
	end
	if name:sub(1, 1) == "=" then
		return false
	end
	if name:find(INVALID_SCRIPT_PATTERN) then
		return false
	end
	if name:find("%[string%]") then
		return false
	end
	return true
end

local function resolveCallerScriptName()
	if Shared.BoundScriptName and isValidScriptName(Shared.BoundScriptName) then
		return Shared.BoundScriptName
	end

	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath and fullPath ~= "" then
			local name = fullPath:match("[/\\]([^/\\]+)$") or fullPath
			if name:match("%.lua$") then
				name = name:gsub("%.lua$", "")
			end
			if isValidScriptName(name) then
				return name
			end
		end
	end

	for level = 2, 16 do
		local info = debug.getinfo(level, "Sln")
		if not info then
			break
		end
		local source = info.source or ""
		if source:sub(1, 1) == "@" then
			source = source:sub(2)
		end
		local fileName = source:match("[/\\]([^/\\]+)$") or source
		if fileName:match("%.lua$") then
			fileName = fileName:gsub("%.lua$", "")
		end
		if isValidScriptName(fileName) then
			return fileName
		end
	end

	return "unknown"
end

local function ensureSessionForScript(scriptName)
	if not isValidScriptName(scriptName) then
		return false
	end
	if Shared.ActiveScriptName == scriptName and Shared.SessionID then
		return true
	end

	if Shared.SessionID then
		Collector.EndSession()
	end

	return Collector.BeginSession(scriptName)
end

local function ensureScriptSession()
	local scriptName = resolveCallerScriptName()
	if not isValidScriptName(scriptName) then
		return false
	end
	if Shared.ActiveScriptName ~= scriptName or not Shared.SessionID then
		return ensureSessionForScript(scriptName)
	end
	return true
end

local Profiler = {}

--- Call from your script after require so session id is not "=[C]_..." from require-time stack.
function Profiler.BindScript(scriptName)
	if isValidScriptName(scriptName) then
		Shared.BoundScriptName = scriptName
	end
end

function Profiler.BeginSession()
	return ensureSessionForScript(resolveCallerScriptName())
end

function Profiler.EndSession()
	Collector.EndSession()
	Shared.ActiveScriptName = nil
end

function Profiler.BeginTick()
	if not ensureScriptSession() then
		return
	end
	Collector.BeginTick()
end

function Profiler.EndTick()
	Collector.EndTick()
end

function Profiler.BeginFrame()
	if not ensureScriptSession() then
		return
	end
	Collector.BeginFrame()
end

function Profiler.EndFrame()
	Collector.EndFrame()
end

function Profiler.Begin(name)
	if not ensureScriptSession() then
		return
	end
	Collector.Begin(name)
end

function Profiler.End(name)
	Collector.End(name)
end

function Profiler.SetEnabled(enabled)
	Collector.SetEnabled(enabled)
end

function Profiler.IsEnabled()
	return Collector.IsEnabled()
end

function Profiler.IsCollectorAvailable()
	return Collector.IsCollectorReachable()
end

function Profiler.GetSessionID()
	return Shared.SessionID
end

function Profiler.GetActiveScript()
	return Shared.ActiveScriptName
end

function Profiler.GetFlameGraphsFolder()
	local sid = Shared.SessionID
	if not sid then
		return nil
	end
	return "timing_collector\\flame_graphs\\" .. sid
end

function Profiler.PrintFlameGraphHelp()
	local sid = Shared.SessionID
	print("============================================================")
	print("[Profiler] Flame graphs (next to timing_collector.exe):")
	print("  C:\\gitProjects\\profiler\\timing_collector\\flame_graphs\\<session_id>\\")
	if sid then
		print("[Profiler] Your session:")
		print("  ...\\flame_graphs\\" .. sid)
	end
	print("[Profiler] Open tick.speedscope.json at https://www.speedscope.app")
	print("============================================================")
end

function Profiler.Unload()
	Collector.EndSession()
	Shared.BoundScriptName = nil
	Shared.ActiveScriptName = nil
end

Profiler.VERSION = "2.0.0"
Profiler.AUTHOR = "titaniummachine1"

package.loaded["Profiler"] = Profiler

return Profiler
