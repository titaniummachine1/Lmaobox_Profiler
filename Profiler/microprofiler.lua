--[[
    Microprofiler Module - Automatic Function Hooking
    Implements automatic function profiling like Roblox microprofiler
    Used by: profiler.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]
local Timing = require("Profiler.timing")

-- Module declaration
local MicroProfiler = {}

-- Local constants / utilities --------

-- API guard to prevent recursion
local inProfilerAPI = false
local autoHookDesired = false

-- Performance limits (tick-based history)
local MAX_TICKS = 66 -- Keep max 66 ticks of history (~1 second at 66 tick rate)
local MAX_TIMELINE_SIZE = 200 -- Functions per timeline
local MAX_CUSTOM_THREADS = 50 -- Custom work items
local CLEANUP_INTERVAL = 0.5 -- Cleanup frequency

-- Context definitions
local Contexts = {
	TICK = {
		id = "tick",
		last_id = 0,
		current_record = 1,
		callStack = {},
		mainTimeline = {},
		customThreads = {},
		activeCustomStack = {},
		scriptTimelines = {},
		callbackBoundaries = {},
	},
	FRAME = {
		id = "frame",
		last_id = 0,
		current_record = 1,
		callStack = {},
		mainTimeline = {},
		customThreads = {},
		activeCustomStack = {},
		scriptTimelines = {},
		callbackBoundaries = {},
	},
}

-- Local state (not global)
local isEnabled = false
local isHooked = false
local isPaused = false
local currentContext = Contexts.TICK
local lastCleanupTime = 0

-- External APIs (Lua 5.4 compatible)
-- Use external globals library (RealTime, FrameTime) directly since it's globally available

-- Private helpers --------------------

-- Forward declaration so later calls see the local, not a global
local autoDisableIfIdle

local function getCurrentTime()
	return Timing.Now()
end

-- Auto-shift context to next record slot
local function autoShiftContext(ctx, forceIncrement)
	assert(ctx, "autoShiftContext: ctx missing")

	if ctx.id == "tick" then
		-- Tick context uses engine tick count
		local engine_id = globals.TickCount()
		if engine_id ~= ctx.last_id then
			ctx.current_record = (ctx.current_record % MAX_TICKS) + 1
			ctx.last_id = engine_id
		end
	else
		-- Frame context increments on every SetContext call
		if forceIncrement then
			ctx.current_record = (ctx.current_record % MAX_TICKS) + 1
			ctx.last_id = (ctx.last_id or 0) + 1
		end
	end
end

-- Get memory usage in KB
local function getMemory()
	return collectgarbage("count")
end

-- Filter array in single pass - O(n) instead of O(n^2) from repeated table.remove
local function filterArray(arr, keepFn)
	local writeIdx = 1
	for readIdx = 1, #arr do
		if keepFn(arr[readIdx]) then
			if writeIdx ~= readIdx then
				arr[writeIdx] = arr[readIdx]
			end
			writeIdx = writeIdx + 1
		end
	end
	-- Nil out remaining slots
	for i = writeIdx, #arr do
		arr[i] = nil
	end
end

-- Cleanup old records for a specific context
local function cleanupContext(ctx)
	assert(ctx, "cleanupContext: ctx missing")

	local currentTime = getCurrentTime()
	local tickInterval = globals.TickInterval()
	local maxHistoryTime = MAX_TICKS * tickInterval
	local cutoffTime = currentTime - maxHistoryTime

	filterArray(ctx.mainTimeline, function(record)
		return not record.endTime or record.endTime >= cutoffTime
	end)

	filterArray(ctx.customThreads, function(thread)
		return not thread.endTime or thread.endTime >= cutoffTime
	end)

	for scriptName, scriptData in pairs(ctx.scriptTimelines) do
		filterArray(scriptData.functions, function(func)
			return not func.endTime or func.endTime >= cutoffTime
		end)

		if #scriptData.functions == 0 then
			ctx.scriptTimelines[scriptName] = nil
		end
	end

	local boundariesToRemove = {}
	for tickNum, boundary in pairs(ctx.callbackBoundaries) do
		local boundaryTime = boundary.startTime or boundary
		if type(boundaryTime) == "number" and boundaryTime < cutoffTime then
			table.insert(boundariesToRemove, tickNum)
		end
	end
	for _, tickNum in ipairs(boundariesToRemove) do
		ctx.callbackBoundaries[tickNum] = nil
	end
end

-- Cleanup old records - ONLY when NOT paused to preserve navigation data
local function cleanupOldRecords()
	if isPaused then
		return
	end

	local currentTime = getCurrentTime()

	if currentTime - lastCleanupTime < CLEANUP_INTERVAL then
		return
	end

	lastCleanupTime = currentTime

	cleanupContext(Contexts.TICK)
	cleanupContext(Contexts.FRAME)
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
		startTime = getCurrentTime(),
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

	if isPaused then
		return
	end

	local currentTime = getCurrentTime()
	if currentTime - lastCleanupTime > CLEANUP_INTERVAL then
		cleanupOldRecords()
		autoDisableIfIdle()
	end

	autoShiftContext(currentContext)

	local info = debug.getinfo(2, "nS")
	if not info then
		return
	end

	if not shouldProfile(info) then
		return
	end

	local ctx = currentContext
	assert(ctx, "profileHook: currentContext missing")

	if event == "call" then
		if #ctx.callStack > 20 then
			return
		end

		local record = createFunctionRecord(info)

		if #ctx.callStack > 0 then
			table.insert(ctx.callStack[#ctx.callStack].children, record)
		end

		table.insert(ctx.callStack, record)
	elseif event == "return" then
		local record = table.remove(ctx.callStack)
		if not record then
			return
		end

		record.endTime = getCurrentTime()
		record.endTick = globals.TickCount()
		record.memDelta = getMemory() - record.memStart
		record.duration = record.endTime - record.startTime

		if record.duration < 0 then
			record.duration = 0
		end

		if #ctx.callStack == 0 then
			if #ctx.mainTimeline >= MAX_TIMELINE_SIZE then
				for i = 1, MAX_TIMELINE_SIZE - 1 do
					ctx.mainTimeline[i] = ctx.mainTimeline[i + 1]
				end
				ctx.mainTimeline[MAX_TIMELINE_SIZE] = record
			else
				ctx.mainTimeline[#ctx.mainTimeline + 1] = record
			end

			local scriptName = record.scriptName
			if not ctx.scriptTimelines[scriptName] then
				ctx.scriptTimelines[scriptName] = {
					name = scriptName,
					functions = {},
					type = "script",
				}
			end

			local funcs = ctx.scriptTimelines[scriptName].functions
			if #funcs >= MAX_TIMELINE_SIZE then
				for i = 1, MAX_TIMELINE_SIZE - 1 do
					funcs[i] = funcs[i + 1]
				end
				funcs[MAX_TIMELINE_SIZE] = record
			else
				funcs[#funcs + 1] = record
			end
		end

		for _, thread in ipairs(ctx.activeCustomStack) do
			if record.startTime >= thread.startTime and (not thread.endTime or record.endTime <= thread.endTime) then
				if #thread.children < 100 then
					local copy = {
						key = record.key,
						name = record.name,
						source = record.source,
						line = record.line,
						startTime = record.startTime,
						endTime = record.endTime,
						duration = record.duration,
						memDelta = record.memDelta,
						children = record.children,
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

-- Internal boundary tracking callbacks (always active for ruler accuracy)
local function trackTickBoundary(cmd)
	if isPaused then
		return
	end

	local tickNum = globals.TickCount()
	local entryTime = getCurrentTime()

	Contexts.TICK.callbackBoundaries[tickNum] = {
		startTime = entryTime,
		duration = globals.TickInterval(),
	}
end

local function trackFrameBoundary()
	if isPaused then
		return
	end

	local frameDuration = globals.AbsoluteFrameTime()
	local entryTime = getCurrentTime()

	Contexts.FRAME.last_id = (Contexts.FRAME.last_id or 0) + 1
	Contexts.FRAME.callbackBoundaries[Contexts.FRAME.last_id] = {
		startTime = entryTime,
		duration = frameDuration > 0 and frameDuration or (1.0 / 60.0),
	}
end

local function registerBoundaryTracking()
	if boundaryTrackingRegistered then
		return
	end

	if not callbacks or not callbacks.Register then
		return
	end

	callbacks.Register("CreateMove", "ProfilerBoundaryTrack_Tick", trackTickBoundary)
	callbacks.Register("Draw", "ProfilerBoundaryTrack_Frame", trackFrameBoundary)
	boundaryTrackingRegistered = true
end

local function unregisterBoundaryTracking()
	if not boundaryTrackingRegistered then
		return
	end

	if callbacks and callbacks.Unregister then
		callbacks.Unregister("CreateMove", "ProfilerBoundaryTrack_Tick")
		callbacks.Unregister("Draw", "ProfilerBoundaryTrack_Frame")
	end
	boundaryTrackingRegistered = false
end

-- Public API -------------------------

function MicroProfiler.Enable()
	isEnabled = true
	registerBoundaryTracking()
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
	local hasData = false
	for _, ctx in pairs(Contexts) do
		if #ctx.mainTimeline > 0 or #ctx.customThreads > 0 then
			hasData = true
			break
		end
		for _ in pairs(ctx.scriptTimelines) do
			hasData = true
			break
		end
		if hasData then
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
		local currentTime = getCurrentTime()
		local currentMem = getMemory()
		local currentTick = globals.TickCount()

		for _, ctx in pairs(Contexts) do
			for i = #ctx.activeCustomStack, 1, -1 do
				local work = ctx.activeCustomStack[i]
				if not work.endTime then
					work.endTime = currentTime
					work.endTick = currentTick
					work.memDelta = currentMem - work.memStart
					work.duration = work.endTime - work.startTime
				end
			end

			for i = #ctx.callStack, 1, -1 do
				local record = ctx.callStack[i]
				if not record.endTime then
					record.endTime = currentTime
					record.endTick = currentTick
					record.memDelta = currentMem - record.memStart
					record.duration = record.endTime - record.startTime
				end
			end

			ctx.activeCustomStack = {}
			ctx.callStack = {}
		end
	elseif not paused and wasPaused then
		MicroProfiler.ClearData()
		if Shared then
			Shared.RecordingStartTime = getCurrentTime()
		end
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

	if not name or name == "" then
		print("BeginCustomWork: name is required")
		return
	end

	if isPaused then
		return
	end

	inProfilerAPI = true

	local scriptName = "Manual Work"
	for level = 3, 10 do
		local info = debug.getinfo(level, "S")
		if not info then
			break
		end
		local source = info.source or ""
		local fileName = source:match("\\([^\\]-)$") or source:match("/([^/]-)$") or source
		if fileName:match("%.lua$") then
			fileName = fileName:gsub("%.lua$", "")
		end
		if fileName ~= "Profiler" and fileName ~= "" and fileName ~= "[C]" and fileName ~= "[string]" then
			scriptName = fileName
			break
		end
	end

	local work = {
		name = name,
		category = category or nil,
		scriptName = scriptName,
		startTime = getCurrentTime(),
		startTick = globals.TickCount(),
		memStart = getMemory(),
		endTime = nil,
		endTick = nil,
		memDelta = 0,
		duration = 0,
		children = {},
		type = "custom",
	}

	local ctx = currentContext
	assert(ctx, "BeginCustomWork: currentContext missing")

	if #ctx.customThreads >= MAX_CUSTOM_THREADS then
		for i = 1, MAX_CUSTOM_THREADS - 1 do
			ctx.customThreads[i] = ctx.customThreads[i + 1]
		end
		ctx.customThreads[MAX_CUSTOM_THREADS] = work
	else
		ctx.customThreads[#ctx.customThreads + 1] = work
	end

	if #ctx.activeCustomStack >= 10 then
		for i = 1, 9 do
			ctx.activeCustomStack[i] = ctx.activeCustomStack[i + 1]
		end
		ctx.activeCustomStack[10] = work
	else
		ctx.activeCustomStack[#ctx.activeCustomStack + 1] = work
	end

	inProfilerAPI = false
end

function MicroProfiler.EndCustomWork(name)
	if not isEnabled or inProfilerAPI or isPaused then
		return
	end

	local ctx = currentContext
	assert(ctx, "EndCustomWork: currentContext missing")

	if not name or name == "" then
		if #ctx.activeCustomStack == 0 then
			inProfilerAPI = false
			return
		end
		name = ctx.activeCustomStack[#ctx.activeCustomStack].name
	end

	inProfilerAPI = true

	local work = nil
	for i = #ctx.activeCustomStack, 1, -1 do
		if ctx.activeCustomStack[i].name == name then
			work = ctx.activeCustomStack[i]
			table.remove(ctx.activeCustomStack, i)
			break
		end
	end

	if work then
		work.endTime = getCurrentTime()
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

		local parentWork = ctx.activeCustomStack[#ctx.activeCustomStack]
		if parentWork then
			parentWork.children = parentWork.children or {}
			table.insert(parentWork.children, workRecord)
		else
			if #ctx.mainTimeline >= MAX_TIMELINE_SIZE then
				for i = 1, MAX_TIMELINE_SIZE - 1 do
					ctx.mainTimeline[i] = ctx.mainTimeline[i + 1]
				end
				ctx.mainTimeline[MAX_TIMELINE_SIZE] = workRecord
			else
				ctx.mainTimeline[#ctx.mainTimeline + 1] = workRecord
			end

			local timelineKey = work.category or work.scriptName or "Manual Work"
			if not ctx.scriptTimelines[timelineKey] then
				ctx.scriptTimelines[timelineKey] = {
					name = timelineKey,
					functions = {},
					type = "script",
				}
			end
			local funcs = ctx.scriptTimelines[timelineKey].functions
			if #funcs >= MAX_TIMELINE_SIZE then
				for i = 1, MAX_TIMELINE_SIZE - 1 do
					funcs[i] = funcs[i + 1]
				end
				funcs[MAX_TIMELINE_SIZE] = workRecord
			else
				funcs[#funcs + 1] = workRecord
			end
		end
	end

	inProfilerAPI = false
end

-- Get profiler data
function MicroProfiler.GetMainTimeline()
	return currentContext.mainTimeline
end

function MicroProfiler.GetCustomThreads()
	return currentContext.customThreads
end

function MicroProfiler.GetScriptTimelines()
	return currentContext.scriptTimelines
end

function MicroProfiler.GetCallStack()
	return currentContext.callStack
end

function MicroProfiler.GetProfilerData()
	return {
		mainTimeline = currentContext.mainTimeline,
		customThreads = currentContext.customThreads,
		scriptTimelines = currentContext.scriptTimelines,
		callStack = currentContext.callStack,
		isEnabled = isEnabled,
		isHooked = isHooked,
		manualTimeline = currentContext.mainTimeline,
		contexts = Contexts,
		currentContext = currentContext,
	}
end

-- Clear collected data
function MicroProfiler.ClearData()
	for _, ctx in pairs(Contexts) do
		ctx.mainTimeline = {}
		ctx.customThreads = {}
		ctx.activeCustomStack = {}
		ctx.callStack = {}
		ctx.scriptTimelines = {}
		ctx.callbackBoundaries = {}
		ctx.last_id = 0
		ctx.current_record = 1
	end
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
	currentContext = Contexts.TICK
end

-- Set active context for profiling
function MicroProfiler.SetContext(contextName)
	assert(contextName == "tick" or contextName == "frame", "SetContext: contextName must be 'tick' or 'frame'")

	local entryTime = getCurrentTime()
	local currentTickCount = globals.TickCount()

	if contextName == "tick" then
		currentContext = Contexts.TICK
		Shared.CurrentContext = "tick"
		autoShiftContext(currentContext, false)
		currentContext.callbackBoundaries[currentTickCount] = {
			startTime = entryTime,
			duration = globals.TickInterval(),
		}
	else
		local frameDuration = globals.AbsoluteFrameTime()
		currentContext = Contexts.FRAME
		Shared.CurrentContext = "frame"
		autoShiftContext(currentContext, true)
		currentContext.callbackBoundaries[currentContext.last_id] = {
			startTime = entryTime,
			duration = frameDuration > 0 and frameDuration or (1.0 / 60.0),
		}
	end
end

function MicroProfiler.GetCurrentContext()
	return currentContext.id
end

-- Get statistics
function MicroProfiler.GetStats()
	local totalFunctions = 0
	local totalCustomThreads = 0
	local activeCustoms = 0
	local callStackDepth = 0
	local totalTime = 0
	local totalMemory = 0

	for _, ctx in pairs(Contexts) do
		totalFunctions = totalFunctions + #ctx.mainTimeline
		totalCustomThreads = totalCustomThreads + #ctx.customThreads
		activeCustoms = activeCustoms + #ctx.activeCustomStack
		callStackDepth = callStackDepth + #ctx.callStack

		for _, func in ipairs(ctx.mainTimeline) do
			totalTime = totalTime + (func.duration or 0)
			totalMemory = totalMemory + (func.memDelta or 0)
		end

		for _, thread in ipairs(ctx.customThreads) do
			totalTime = totalTime + (thread.duration or 0)
			totalMemory = totalMemory + (thread.memDelta or 0)
		end
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
		currentContext = currentContext.id,
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

	print("=== Main Timeline (Current Context: " .. currentContext.id .. ") ===")
	for i, func in ipairs(currentContext.mainTimeline) do
		local prefix = (i == #currentContext.mainTimeline) and "└─ " or "├─ "
		printNode(func, 0, prefix)
	end

	print("=== Custom Threads ===")
	for i, thread in ipairs(currentContext.customThreads) do
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
