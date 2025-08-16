--[[
    Microprofiler Module - Automatic Function Hooking
    Implements automatic function profiling like Roblox microprofiler
    Used by: profiler.lua
]]

-- Imports
local G = require("Profiler.globals") --[[ Imported by: profiler ]]

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

-- Performance limits (MINIMAL for performance)
local MAX_RECORD_TIME = 2.0 -- Keep records for 2 seconds max
local MAX_TIMELINE_SIZE = 15 -- Limit main timeline to 15 records (AGGRESSIVE)
local MAX_CUSTOM_THREADS = 3 -- Limit custom threads (AGGRESSIVE)
local CLEANUP_INTERVAL = 0.5 -- Clean up every 0.5 seconds (AGGRESSIVE)

-- Global variables for retained mode (not local)
isEnabled = false
isHooked = false
isPaused = isPaused or false -- Add pause state
callStack = callStack or {}
mainTimeline = mainTimeline or {}
customThreads = customThreads or {}
activeCustomStack = activeCustomStack or {}
lastCleanupTime = lastCleanupTime or 0

-- Script-separated timelines for better organization
scriptTimelines = scriptTimelines or {} -- { [scriptName] = { functions = {}, name = scriptName } }

-- External APIs (Lua 5.4 compatible)
local globals = (_G and _G.globals) or nil

-- Private helpers --------------------

-- Get high precision time
local function getTime()
	return (globals and globals.RealTime) and globals.RealTime() or 0
end

-- Get memory usage in KB
local function getMemory()
	return collectgarbage("count")
end

-- Cleanup old records to prevent memory leaks and lag
local function cleanupOldRecords()
	local currentTime = getTime()

	-- Skip if not enough time has passed
	if currentTime - lastCleanupTime < CLEANUP_INTERVAL then
		return
	end

	lastCleanupTime = currentTime

	-- Clean main timeline - remove records older than MAX_RECORD_TIME
	local i = 1
	while i <= #mainTimeline do
		local record = mainTimeline[i]
		if record.endTime and (currentTime - record.endTime) > MAX_RECORD_TIME then
			table.remove(mainTimeline, i)
		else
			i = i + 1
		end
	end

	-- Limit main timeline size
	while #mainTimeline > MAX_TIMELINE_SIZE do
		table.remove(mainTimeline, 1)
	end

	-- Clean custom threads
	local j = 1
	while j <= #customThreads do
		local thread = customThreads[j]
		if thread.endTime and (currentTime - thread.endTime) > MAX_RECORD_TIME then
			table.remove(customThreads, j)
		else
			j = j + 1
		end
	end

	-- Limit custom threads
	while #customThreads > MAX_CUSTOM_THREADS do
		table.remove(customThreads, 1)
	end

	-- Clean active custom stack of completed threads
	local k = 1
	while k <= #activeCustomStack do
		local thread = activeCustomStack[k]
		if thread.endTime then
			table.remove(activeCustomStack, k)
		else
			k = k + 1
		end
	end

	-- Clean script timelines
	for scriptName, scriptData in pairs(scriptTimelines) do
		local m = 1
		while m <= #scriptData.functions do
			local func = scriptData.functions[m]
			if func.endTime and (currentTime - func.endTime) > MAX_RECORD_TIME then
				table.remove(scriptData.functions, m)
			else
				m = m + 1
			end
		end

		-- Remove empty script timelines
		if #scriptData.functions == 0 then
			scriptTimelines[scriptName] = nil
		end
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
	if _G.GetScriptName then
		local fullPath = _G.GetScriptName()
		if fullPath then
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	end

	-- STRICT FILTERING: Only allow actual user scripts, block profiler completely
	if scriptName:find("Profiler", 1, true) or scriptName == "Local" or scriptName == "Unknown" then
		return false -- Skip profiler-related scripts and unknowns
	end

    -- Allow all user scripts; previously restricted to example.lua which hid data

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
	if _G.GetScriptName then
		local fullPath = _G.GetScriptName()
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
		startTime = getTime(),
		memStart = getMemory(),
		endTime = nil,
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

	-- Skip expensive operations if paused
	if isPaused then
		return -- Don't profile when paused = instant lag fix
	end

	-- Only cleanup occasionally to reduce overhead
	local currentTime = getTime()
	if currentTime - lastCleanupTime > CLEANUP_INTERVAL then
		cleanupOldRecords()
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
		record.endTime = getTime()
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
	if not isHooked and isEnabled then
		-- Test if debug.sethook is available
		if not debug or not debug.sethook then
			print("❌ WARNING: debug.sethook is not available in lmaobox environment!")
			print("   Automatic function profiling disabled. Manual profiling still works.")
			return
		end

		print("🔧 Setting up debug hook for automatic profiling...")

		-- Try to set the hook safely
		local success, err = pcall(function()
			debug.sethook(profileHook, "cr")
		end)

		if not success then
			print("❌ ERROR: Failed to set debug hook: " .. tostring(err))
			print("   Automatic profiling disabled. Manual profiling still works.")
			return
		end

		isHooked = true
		print("✅ Debug hook enabled successfully!")

		-- Test hook with a simple function call
		local function testHook()
			-- This should trigger the hook
		end
		testHook()
	end
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
	enableHook()
end

function MicroProfiler.Disable()
	isEnabled = false
	disableHook()
end

function MicroProfiler.IsEnabled()
	return isEnabled
end

function MicroProfiler.IsHooked()
	return isHooked
end

function MicroProfiler.SetPaused(paused)
	isPaused = paused

	if paused then
		-- Just set pause flag - keep hook enabled for immediate resume
		print("⏸️ Profiler PAUSED - recording stopped (automatic + manual)")
	else
		-- Resume recording
		print("▶️ Profiler RESUMED - recording started (automatic + manual)")
		-- Ensure hook is enabled when resuming
		if isEnabled and not isHooked then
			enableHook()
		end
	end
end

function MicroProfiler.IsPaused()
	return isPaused
end

-- Manual profiling for custom threads (with API guards)
function MicroProfiler.BeginCustomThread(name)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- DOUBLE CHECK: Make sure we're really not paused
	if isPaused then
		return
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	-- Use lmaobox GetScriptName() with proper Windows path handling
	local scriptName = "Manual Thread"
	if _G.GetScriptName then
		local fullPath = _G.GetScriptName()
		if fullPath then
			-- Extract filename from Windows path and remove .lua extension for display
			scriptName = fullPath:match("\\([^\\]-)$") or fullPath:match("/([^/]-)$") or fullPath
			if scriptName:match("%.lua$") then
				scriptName = scriptName:gsub("%.lua$", "")
			end
		end
	end

	-- Clean up bundled script names
	if scriptName == "Profiler" then
		scriptName = "example" -- User's actual script when bundled
	end

	local thread = {
		name = name,
		scriptName = scriptName,
		startTime = getTime(),
		memStart = getMemory(),
		endTime = nil,
		memDelta = 0,
		duration = 0,
		children = {},
		type = "custom",
	}

	table.insert(customThreads, thread)
	table.insert(activeCustomStack, thread)

	print(string.format("🎯 Manual profiling started: %s (Script: %s)", name, scriptName))

	-- Limit custom threads more aggressively
	while #customThreads > MAX_CUSTOM_THREADS do
		table.remove(customThreads, 1)
	end

	-- Clean up if we have too many active threads
	if #activeCustomStack > 10 then
		table.remove(activeCustomStack, 1)
	end

	-- Clear API guard
	inProfilerAPI = false
end

function MicroProfiler.EndCustomThread()
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	-- DOUBLE CHECK: Make sure we're really not paused
	if isPaused then
		return
	end

	-- Set API guard to prevent recursion
	inProfilerAPI = true

	local thread = table.remove(activeCustomStack)
	if not thread then
		print("❌ EndCustomThread called but no active thread!")
		inProfilerAPI = false
		return
	end

	thread.endTime = getTime()
	thread.memDelta = getMemory() - thread.memStart
	thread.duration = thread.endTime - thread.startTime

	-- Validate timing
	if thread.duration < 0 then
		thread.duration = 0
	end

	print(
		string.format("✅ Manual profiling completed: %s (%.3fms)", thread.name or "unnamed", thread.duration * 1000)
	)

	-- IMPORTANT: Add to script timeline so it shows up in UI - FORCE SAME SCRIPT
	local scriptName = "example" -- FORCE all manual profiling to "example" script to group together
	if not scriptTimelines[scriptName] then
		scriptTimelines[scriptName] = {
			name = scriptName,
			functions = {},
			type = "script",
		}
	end

	-- Create a function record for the thread
	local threadRecord = {
		key = thread.name,
		name = thread.name,
		source = "manual",
		scriptName = scriptName,
		line = 0,
		startTime = thread.startTime,
		endTime = thread.endTime,
		duration = thread.duration,
		memDelta = thread.memDelta,
		children = thread.children,
	}

	-- Add to script timeline for UI display (same script as automatic profiling)
	table.insert(scriptTimelines[scriptName].functions, threadRecord)

	-- Also add to main timeline
	table.insert(mainTimeline, threadRecord)

	print(string.format("📊 Manual profiling added to script timeline: %s", scriptName))

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
	local currentTime = getTime()
	if (G and G.DEBUG) and (currentTime - _lastStatsTime > 5.0) then
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
