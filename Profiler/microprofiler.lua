--[[
    Microprofiler Module - Automatic Function Hooking
    Implements automatic function profiling like Roblox microprofiler
    Used by: profiler.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]

-- Module declaration
local MicroProfiler = {}

-- Local constants / utilities --------
-- Immutable constants (Lua 5.4 compatible)
local PROFILER_SOURCES = {
	"profiler.lua",
	"microprofiler.lua",
	"ui_top.lua",
	"ui_body.lua",
	"Main.lua",
	"globals.lua",
	"config.lua",
	"Profiler.lua", -- Bundled version
}

-- API guard to prevent recursion
local inProfilerAPI = false
local autoHookDesired = false

-- Performance limits (tick-based history)
local MAX_TICKS = 66 -- Keep max 66 ticks of history (~1 second at 66 tick rate)
local MAX_TIMELINE_SIZE = 200 -- Functions per timeline
local MAX_CUSTOM_THREADS = 50 -- Custom work items
local CLEANUP_INTERVAL = 0.5 -- Cleanup frequency

-- Local state (not global)
local isEnabled = false
local isHooked = false
local isPaused = false
local callStack = {}
local mainTimeline = {}
local customThreads = {}
local activeCustomStack = {}
local lastCleanupTime = 0
local scriptTimelines = {}

-- External APIs (Lua 5.4 compatible)
-- Use external globals library (RealTime, FrameTime) directly since it's globally available

-- Private helpers --------------------

-- Forward declaration so later calls see the local, not a global
local autoDisableIfIdle

-- Use os.clock() for microsecond-level timing precision

-- Get memory usage in KB
local function getMemory()
	return collectgarbage("count")
end

-- Track when profiler was paused for cleanup reference
local pauseStartTime = nil

-- Cleanup old records - ONLY when NOT paused to preserve navigation data
local function cleanupOldRecords()
	-- DON'T cleanup when paused - keep ALL data for navigation
	if isPaused then
		return
	end

	local currentTime = os.clock()

	-- Skip if not enough time has passed
	if currentTime - lastCleanupTime < CLEANUP_INTERVAL then
		return
	end

	lastCleanupTime = currentTime
	local functionsRemoved = 0

	-- Tick-based cleanup: keep only last MAX_TICKS worth of data
	local tickInterval = globals.TickInterval()
	local maxHistoryTime = MAX_TICKS * tickInterval
	local cutoffTime = currentTime - maxHistoryTime

	-- Clean main timeline - remove records older than cutoff
	local i = 1
	while i <= #mainTimeline do
		local record = mainTimeline[i]
		if record.endTime and record.endTime < cutoffTime then
			table.remove(mainTimeline, i)
			functionsRemoved = functionsRemoved + 1
		else
			i = i + 1
		end
	end

	-- Clean custom threads
	local j = 1
	while j <= #customThreads do
		local thread = customThreads[j]
		if thread.endTime and thread.endTime < cutoffTime then
			table.remove(customThreads, j)
			functionsRemoved = functionsRemoved + 1
		else
			j = j + 1
		end
	end

	-- Clean script timelines
	for scriptName, scriptData in pairs(scriptTimelines) do
		local m = 1
		while m <= #scriptData.functions do
			local func = scriptData.functions[m]
			if func.endTime and func.endTime < cutoffTime then
				table.remove(scriptData.functions, m)
				functionsRemoved = functionsRemoved + 1
			else
				m = m + 1
			end
		end

		-- Remove empty script timelines
		if #scriptData.functions == 0 then
			scriptTimelines[scriptName] = nil
		end
	end

	-- Only report if significant cleanup happened
	if functionsRemoved > 10 then
		print(string.format("🧹 Cleanup: removed %d old functions while running", functionsRemoved))
	end
end

-- Check if we should profile this function (FIXED: Not too aggressive)
local function shouldProfile(info)
	-- Guard against profiler API recursion
	if inProfilerAPI then
		return false
	end

	if not info or not info.short_src then
		return false
	end

	-- Enhanced string matching
	local source = info.short_src
	local name = info.name or ""

	-- Skip built-in Lua functions and C functions FIRST
	if source == "=[C]" or source == "=[string]" or source == "" then
		return false
	end

	-- Skip common built-in function names that cause overhead
	if
		name == "pairs"
		or name == "ipairs"
		or name == "next"
		or name == "type"
		or name == "tostring"
		or name == "tonumber"
		or name == "getmetatable"
		or name == "setmetatable"
		or name == "rawget"
		or name == "rawset"
		or name == "pcall"
		or name == "xpcall"
		or name == "require"
		or name == "sethook"
		or name == "getinfo"
	then
		return false
	end

	-- ONLY skip actual profiler internal functions by name
	if
		name
		and (
			name:find("profileHook", 1, true)
			or name:find("shouldProfile", 1, true)
			or name:find("createFunctionRecord", 1, true)
			or name:find("cleanupOldRecords", 1, true)
			or name:find("enableHook", 1, true)
			or name:find("disableHook", 1, true)
			or name:find("testHook", 1, true)
		)
	then
		return false
	end

	-- COMPLETELY FILTER OUT "Local//Profiler" functions
	-- Use GetScriptName to determine real script
	local scriptName = "Unknown"
	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath then
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	end

	-- STRICT FILTERING: Only allow actual user scripts, block profiler completely
	if scriptName:find("Profiler", 1, true) or scriptName == "Local" then
		return false -- Skip profiler-related scripts
	end

	-- Allow ALL user scripts (including unknown ones) for auto-hooking
	-- Debug: Show what scripts we're profiling (always show for debugging)
	if scriptName ~= "Unknown" then
		print(string.format("🔍 Auto-profiling script: %s (function: %s)", scriptName, name or "unnamed"))
	end

	-- Skip internal profiler functions by name
	if
		name
		and (
			name:find("MicroProfiler", 1, true)
			or name:find("UITop", 1, true)
			or name:find("UIBody", 1, true)
			or name:find("ProfilerCore", 1, true)
			or name:find("safeCoord", 1, true)
			or name:find("safeFilledRect", 1, true)
		)
	then
		return false
	end

	return true
end

-- Create function record with script separation
local function createFunctionRecord(info)
	local name = info.name or "anonymous"
	local source = info.short_src or "unknown"
	local line = info.linedefined or 0

	-- Use lmaobox GetScriptName() with proper Windows path handling
	local scriptName = "Unknown Script"
	if GetScriptName then
		local fullPath = GetScriptName()
		if fullPath then
			-- Extract filename from Windows path and remove .lua extension for display
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	else
		-- Fallback: Extract script name from source
		scriptName = source:match("[^/\\]+$") or source
		if scriptName == "" or scriptName == "unknown" then
			scriptName = "Unknown Script"
		end
		if scriptName:match("%.lua$") then
			scriptName = scriptName:gsub("%.lua$", "")
		end
	end

	-- Clean up bundled script names
	if scriptName == "Profiler" then
		scriptName = "example" -- User's actual script when bundled
	end

	-- Create a more readable key (Lua 5.4 enhanced)
	local key = name
	if name == "anonymous" then
		key = string.format("%s:%d", scriptName, line)
	end

	return {
		key = key,
		name = name,
		source = source,
		scriptName = scriptName,
		line = line,
		startTime = os.clock(),
		startTick = globals.TickCount(),
		memStart = getMemory(),
		endTime = nil,
		endTick = nil,
		memDelta = 0,
		duration = 0,
		children = {},
	}
end

-- Hook function for automatic profiling (SIMPLIFIED for performance)
local function profileHook(event)
	if not isEnabled or inProfilerAPI then
		return
	end

	-- Skip profiling if paused
	if isPaused then
		return -- Don't profile when paused = instant lag fix
	end

	-- Only cleanup when NOT paused to keep data available for navigation
	local currentTime = os.clock()
	if currentTime - lastCleanupTime > CLEANUP_INTERVAL then
		cleanupOldRecords()
		autoDisableIfIdle()
	end

	-- MINIMAL info gathering for performance
	local info = debug.getinfo(2, "nS")
	if not info then
		return
	end

	if not shouldProfile(info) then
		return
	end

	if event == "call" then
		-- Limit call stack depth to prevent excessive nesting overhead
		if #callStack > 20 then
			return
		end

		local record = createFunctionRecord(info)

		-- Add to parent if we're nested
		if #callStack > 0 then
			table.insert(callStack[#callStack].children, record)
		end

		table.insert(callStack, record)
	elseif event == "return" then
		local record = table.remove(callStack)
		if not record then
			return
		end

		-- Complete the record
		record.endTime = os.clock()
		record.endTick = globals.TickCount()
		record.memDelta = getMemory() - record.memStart
		record.duration = record.endTime - record.startTime

		-- Validate timing
		if record.duration < 0 then
			record.duration = 0
		end

		-- If this is a top-level function, add to both main timeline and script timeline
		if #callStack == 0 then
			table.insert(mainTimeline, record)

			-- DEBUG: Print when we add functions to timeline
			if not _timelineDebugCount then
				_timelineDebugCount = 0
			end
			_timelineDebugCount = _timelineDebugCount + 1

			if _timelineDebugCount <= 3 then -- Show first 3 functions added
				print(
					string.format(
						"✅ Added to timeline: %s (%.3fms) from %s",
						record.name or "unnamed",
						record.duration * 1000,
						record.scriptName or "unknown"
					)
				)
			end

			-- Limit timeline size more aggressively
			if #mainTimeline > MAX_TIMELINE_SIZE then
				table.remove(mainTimeline, 1)
			end

			-- Add to script-specific timeline
			local scriptName = record.scriptName
			if not scriptTimelines[scriptName] then
				scriptTimelines[scriptName] = {
					name = scriptName,
					functions = {},
					type = "script",
				}
			end

			-- Add copy to script timeline
			local scriptRecord = {
				key = record.key,
				name = record.name,
				source = record.source,
				scriptName = record.scriptName,
				line = record.line,
				startTime = record.startTime,
				endTime = record.endTime,
				duration = record.duration,
				memDelta = record.memDelta,
				children = record.children, -- Reference to same children
			}
			table.insert(scriptTimelines[scriptName].functions, scriptRecord)

			-- Limit script timeline size
			if #scriptTimelines[scriptName].functions > MAX_TIMELINE_SIZE then
				table.remove(scriptTimelines[scriptName].functions, 1)
			end
		end

		-- Copy to active custom threads if within their timeframe
		for _, thread in ipairs(activeCustomStack) do
			if record.startTime >= thread.startTime and (not thread.endTime or record.endTime <= thread.endTime) then
				-- Create a copy for the custom thread (only if thread isn't full)
				if #thread.children < 100 then -- Limit children per thread
					local copy = {
						key = record.key,
						name = record.name,
						source = record.source,
						line = record.line,
						startTime = record.startTime,
						endTime = record.endTime,
						duration = record.duration,
						memDelta = record.memDelta,
						children = record.children, -- Shallow copy of children
					}
					table.insert(thread.children, copy)
				end
			end
		end
	end
end

-- Enable automatic profiling hook
local function enableHook()
	if not autoHookDesired or isHooked or not isEnabled then
		return
	end

	if not debug or not debug.sethook then
		print("❌ WARNING: debug.sethook is not available. Auto-hooking remains disabled; manual profiling only.")
		return
	end

	local success, err = pcall(function()
		debug.sethook(profileHook, "cr")
	end)

	if not success then
		print("❌ ERROR: Failed to set debug hook: " .. tostring(err))
		print("   Automatic profiling disabled. Manual profiling still works.")
		return
	end

	isHooked = true
	print("✅ Debug hook enabled (manual opt-in)")
end

-- Disable automatic profiling hook
local function disableHook()
	if isHooked then
		debug.sethook(nil, "")
		isHooked = false
	end
end

-- Public API -------------------------

function MicroProfiler.Enable()
	isEnabled = true
	if autoHookDesired then
		enableHook()
	else
		disableHook()
	end
end

function MicroProfiler.Disable()
	isEnabled = false
	disableHook()
end

-- Auto-disable when idle (no data and not paused) - to avoid lingering hooks
function autoDisableIfIdle()
	if not isEnabled or isPaused then
		return
	end
	local hasData = (#mainTimeline > 0) or (#customThreads > 0)
	if not hasData then
		for _ in pairs(scriptTimelines) do
			hasData = true
			break
		end
	end
	if not hasData then
		disableHook()
	end
end

function MicroProfiler.IsEnabled()
	return isEnabled
end

function MicroProfiler.IsHooked()
	return isHooked
end

function MicroProfiler.SetAutoHookEnabled(enabled)
	autoHookDesired = not not enabled
	if not autoHookDesired then
		disableHook()
	elseif isEnabled then
		enableHook()
	end
end

function MicroProfiler.IsAutoHookEnabled()
	return autoHookDesired
end

function MicroProfiler.SetPaused(paused)
	local wasPaused = isPaused
	isPaused = paused

	if paused and not wasPaused then
		-- Just paused - STOP cleanup to preserve data for navigation
		print("⏸️ Profiler PAUSED - recording stopped, data preserved for navigation")
	elseif not paused and wasPaused then
		-- Just resumed - CLEAR ALL DATA and start fresh recording
		print("▶️ Profiler RESUMED - clearing old data, starting fresh recording")
		MicroProfiler.ClearData()
		-- Reset recording start time for fresh timeline
		if Shared then
			Shared.RecordingStartTime = os.clock()
		end
		-- Ensure hook is enabled when resuming
		if isEnabled and not isHooked then
			enableHook()
		end
	end
end

function MicroProfiler.IsPaused()
	return isPaused
end

-- Manual profiling for custom work items (with API guards)
function MicroProfiler.BeginCustomWork(name, category)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- Validate name
	if not name or name == "" then
		print("BeginCustomWork: name is required")
		return
	end

	-- DOUBLE CHECK: Make sure we're really not paused
	if isPaused then
		return
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	-- Walk the callstack to find the REAL calling script (not Profiler itself)
	local scriptName = "Manual Work"
	for level = 3, 10 do
		local info = debug.getinfo(level, "S")
		if not info then
			break
		end
		local source = info.source or ""
		-- Extract script name from source path
		local fileName = source:match("\\([^\\]-)$") or source:match("/([^/]-)$") or source
		if fileName:match("%.lua$") then
			fileName = fileName:gsub("%.lua$", "")
		end
		-- Skip profiler internals, use first user script we find
		if fileName ~= "Profiler" and fileName ~= "" and fileName ~= "[C]" and fileName ~= "[string]" then
			scriptName = fileName
			break
		end
	end

	local work = {
		name = name,
		category = category or nil,
		scriptName = scriptName,
		startTime = os.clock(),
		startTick = globals.TickCount(),
		memStart = getMemory(),
		endTime = nil,
		endTick = nil,
		memDelta = 0,
		duration = 0,
		children = {},
		type = "custom",
	}

	table.insert(customThreads, work)
	table.insert(activeCustomStack, work)

	-- Limit custom work items more aggressively
	while #customThreads > MAX_CUSTOM_THREADS do
		table.remove(customThreads, 1)
	end

	-- Clean up if we have too many active work items
	if #activeCustomStack > 10 then
		table.remove(activeCustomStack, 1)
	end

	-- Clear API guard
	inProfilerAPI = false
end

function MicroProfiler.EndCustomWork(name)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- If no name provided, pop the most-recent active work
	if not name or name == "" then
		if #activeCustomStack == 0 then
			inProfilerAPI = false
			return -- nothing to end
		end
		name = activeCustomStack[#activeCustomStack].name
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	-- Find the matching work item by name
	local work = nil
	for i = #activeCustomStack, 1, -1 do
		if activeCustomStack[i].name == name then
			work = activeCustomStack[i]
			table.remove(activeCustomStack, i)
			break
		end
	end

	if work then
		work.endTime = os.clock()
		work.endTick = globals.TickCount()
		work.memDelta = getMemory() - work.memStart
		work.duration = work.endTime - work.startTime

		local workRecord = {
			key = work.name,
			name = work.name,
			category = work.category,
			source = "manual",
			scriptName = work.scriptName,
			line = 0,
			startTime = work.startTime,
			startTick = work.startTick,
			endTime = work.endTime,
			endTick = work.endTick,
			duration = work.duration,
			memDelta = work.memDelta,
			children = work.children,
		}

		local parentWork = activeCustomStack[#activeCustomStack]
		if parentWork then
			parentWork.children = parentWork.children or {}
			table.insert(parentWork.children, workRecord)
		else
			table.insert(mainTimeline, workRecord)
			if #mainTimeline > MAX_TIMELINE_SIZE then
				table.remove(mainTimeline, 1)
			end

			local timelineKey = work.category or work.scriptName or "Manual Work"
			if not scriptTimelines[timelineKey] then
				scriptTimelines[timelineKey] = {
					name = timelineKey,
					functions = {},
					type = "script",
				}
			end
			table.insert(scriptTimelines[timelineKey].functions, workRecord)
			if #scriptTimelines[timelineKey].functions > MAX_TIMELINE_SIZE then
				table.remove(scriptTimelines[timelineKey].functions, 1)
			end
		end
	end

	-- Clear API guard
	inProfilerAPI = false
end

-- Get profiler data
function MicroProfiler.GetMainTimeline()
	return mainTimeline
end

function MicroProfiler.GetCustomThreads()
	return customThreads
end

function MicroProfiler.GetScriptTimelines()
	return scriptTimelines
end

function MicroProfiler.GetCallStack()
	return callStack
end

function MicroProfiler.GetProfilerData()
	return {
		mainTimeline = mainTimeline,
		customThreads = customThreads,
		scriptTimelines = scriptTimelines,
		callStack = callStack,
		isEnabled = isEnabled,
		isHooked = isHooked,
		manualTimeline = mainTimeline,
	}
end

-- Clear collected data
function MicroProfiler.ClearData()
	mainTimeline = {}
	customThreads = {}
	activeCustomStack = {}
	callStack = {}
	scriptTimelines = {}
end

-- Reset profiler state
function MicroProfiler.Reset()
	disableHook()
	MicroProfiler.ClearData()
	isEnabled = false
	isHooked = false
	isPaused = false
	inProfilerAPI = false
	lastCleanupTime = 0
end

-- Get statistics
function MicroProfiler.GetStats()
	local totalFunctions = #mainTimeline
	local totalCustomThreads = #customThreads
	local activeCustoms = #activeCustomStack
	local callStackDepth = #callStack

	-- Calculate total time covered
	local totalTime = 0
	local totalMemory = 0

	for _, func in ipairs(mainTimeline) do
		totalTime = totalTime + (func.duration or 0)
		totalMemory = totalMemory + (func.memDelta or 0)
	end

	for _, thread in ipairs(customThreads) do
		totalTime = totalTime + (thread.duration or 0)
		totalMemory = totalMemory + (thread.memDelta or 0)
	end

	-- DEBUG: Print status every 5 seconds (guarded by DEBUG)
	if not _lastStatsTime then
		_lastStatsTime = 0
	end
	local currentTime = os.clock()
	if (Shared and Shared.DEBUG) and (currentTime - _lastStatsTime > 5.0) then
		_lastStatsTime = currentTime
		-- Count script timelines
		local scriptCount = 0
		for _ in pairs(scriptTimelines) do
			scriptCount = scriptCount + 1
		end

		print(
			string.format(
				"📊 Profiler Status: %d functions in timeline, %d script timelines, enabled=%s, hooked=%s",
				totalFunctions,
				scriptCount,
				tostring(isEnabled),
				tostring(isHooked)
			)
		)
	end

	return {
		totalFunctions = totalFunctions,
		totalCustomThreads = totalCustomThreads,
		activeCustoms = activeCustoms,
		callStackDepth = callStackDepth,
		totalTime = totalTime,
		totalMemory = totalMemory,
		isEnabled = isEnabled,
		isHooked = isHooked,
	}
end

-- Debug information
function MicroProfiler.PrintStats()
	local stats = MicroProfiler.GetStats()
	print("=== MicroProfiler Stats ===")
	print("Enabled:", stats.isEnabled)
	print("Hooked:", stats.isHooked)
	print("Main timeline functions:", stats.totalFunctions)
	print("Custom threads:", stats.totalCustomThreads)
	print("Active custom threads:", stats.activeCustoms)
	print("Call stack depth:", stats.callStackDepth)
	-- Using Lua 5.4 enhanced string formatting
	print(string.format("Total time: %.6fs", stats.totalTime))
	print(string.format("Total memory: %.2fKB", stats.totalMemory))
end

-- Print timeline hierarchy (for debugging)
function MicroProfiler.PrintTimeline(maxDepth)
	maxDepth = maxDepth or 3

	local function printNode(node, depth, prefix)
		if depth > maxDepth then
			return
		end

		local indent = string.rep("  ", depth)
		local name = node.name or node.key or "unknown"
		local duration = node.duration and string.format("%.3fms", node.duration * 1000) or "0ms"
		local memory = node.memDelta and string.format("%.1fKB", node.memDelta) or "0KB"

		-- Using Lua 5.4 enhanced string formatting
		print(string.format("%s%s%s | %s | %s", indent, prefix, name, duration, memory))

		if node.children then
			for i, child in ipairs(node.children) do
				local childPrefix = (i == #node.children) and "└─ " or "├─ "
				printNode(child, depth + 1, childPrefix)
			end
		end
	end

	print("=== Main Timeline ===")
	for i, func in ipairs(mainTimeline) do
		local prefix = (i == #mainTimeline) and "└─ " or "├─ "
		printNode(func, 0, prefix)
	end

	print("=== Custom Threads ===")
	for i, thread in ipairs(customThreads) do
		print("Thread: " .. (thread.name or "Unnamed"))
		for j, func in ipairs(thread.children) do
			local prefix = (j == #thread.children) and "└─ " or "├─ "
			printNode(func, 0, prefix)
		end
	end
end

-- Self-initialization
-- Don't auto-enable, let the main profiler control this

return MicroProfiler
