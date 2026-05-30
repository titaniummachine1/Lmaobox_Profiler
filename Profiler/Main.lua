--[[
    Profiler — thin Lua client for Go timing_collector.
    API version 2.0 — if require returns a table without SetEnabled, clear package.loaded["Profiler"] and require again.

    Usage:
        local Profiler = require("Profiler")

        callbacks.Register("CreateMove", "my_tick", function(cmd)
            Profiler.BeginTick()
            Profiler.Begin("Work")
            -- ...
            Profiler.End("Work")
            Profiler.EndTick()
        end)

        callbacks.Register("Draw", "my_frame", function()
            Profiler.BeginFrame()
            -- ...
            Profiler.EndFrame()
        end)

    Run timing_collector.exe before profiling. Output: flame_graphs/<session_id>/
]]

-- Drop stale library cached before deploy (old in-game UI profiler had no SetEnabled).
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

local PACKAGES_TO_CLEAR = {
	"Profiler",
	"Profiler.collector",
	"Profiler.timing",
	"Profiler.Shared",
	"Profiler.config",
	"Profiler.Main",
}

local function clearPackageCache()
	for _, pkg in ipairs(PACKAGES_TO_CLEAR) do
		package.loaded[pkg] = nil
	end
end

local function resolveCallerScriptName()
	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath and fullPath ~= "" then
			local name = fullPath:match("[/\\]([^/\\]+)$") or fullPath
			if name:match("%.lua$") then
				name = name:gsub("%.lua$", "")
			end
			if name ~= "" and name ~= "Profiler" then
				return name
			end
		end
	end

	for level = 2, 12 do
		local info = debug.getinfo(level, "S")
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
		if fileName ~= "" and fileName ~= "Profiler" and fileName ~= "[C]" then
			return fileName
		end
	end

	return "unknown"
end

local function onScriptUnload()
	Collector.EndSession()
	if callbacks and callbacks.Unregister then
		callbacks.Unregister("Unload", Shared.UnloadCallbackTag)
	end
end

local function ensureSessionForScript(scriptName)
	if Shared.ActiveScriptName == scriptName and Shared.SessionID then
		return
	end

	if Shared.SessionID then
		Collector.EndSession()
	end

	Collector.BeginSession(scriptName)
end

local function ensureScriptSession()
	local scriptName = resolveCallerScriptName()
	if Shared.ActiveScriptName ~= scriptName or not Shared.SessionID then
		ensureSessionForScript(scriptName)
	end
end

local callerScript = resolveCallerScriptName()
ensureSessionForScript(callerScript)

if not Shared.SessionID then
	print(
	"[Profiler] timing_collector not running — start timing_collector.exe (see README). Spans are no-ops until connected."
	)
end

if callbacks and callbacks.Register then
	callbacks.Unregister("Unload", Shared.UnloadCallbackTag)
	callbacks.Register("Unload", Shared.UnloadCallbackTag, onScriptUnload)
end

local Profiler = {}

function Profiler.BeginSession()
	return Collector.BeginSession(resolveCallerScriptName())
end

function Profiler.EndSession()
	Collector.EndSession()
	Shared.ActiveScriptName = nil
end

function Profiler.BeginTick()
	ensureScriptSession()
	Collector.BeginTick()
end

function Profiler.EndTick()
	Collector.EndTick()
end

function Profiler.BeginFrame()
	ensureScriptSession()
	Collector.BeginFrame()
end

function Profiler.EndFrame()
	Collector.EndFrame()
end

function Profiler.Begin(name)
	ensureScriptSession()
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

function Profiler.PrintFlameGraphHelp()
	local sid = Shared.SessionID
	print("============================================================")
	print("[Profiler] Flame graphs are written by timing_collector.exe")
	print("[Profiler] Folder (next to the .exe):")
	print("  timing_collector\\flame_graphs\\<session_id>\\")
	if sid then
		print("[Profiler] Your session id: " .. sid)
	end
	print("[Profiler] Open tick.speedscope.json at https://www.speedscope.app")
	print("============================================================")
end

function Profiler.Unload()
	onScriptUnload()
	clearPackageCache()
end

Profiler.VERSION = "2.0.0"
Profiler.AUTHOR = "titaniummachine1"

package.loaded["Profiler"] = Profiler

return Profiler
