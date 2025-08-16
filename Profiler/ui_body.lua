--[[
    UI Body Module - Main Profiler Display
    Handles the main profiler body with threads and function hierarchy
    Used by: profiler.lua
]]

-- Imports
local G = require("Profiler.globals") --[[ Imported by: profiler ]]
local config = require("Profiler.config")

-- Module declaration
local UIBody = {}

-- Local constants / utilities -------- (Lua 5.4 compatible)
local THREAD_HEIGHT = 24
local THREAD_SPACING = 2
local MIN_BAR_WIDTH = 2
local HEADER_HEIGHT = 20
local NESTING_INDENT = 16
local DEFAULT_ZOOM = 1.0
local MIN_ZOOM = 0.01 -- Much more zoom out
local MAX_ZOOM = 100.0 -- Much more zoom in for precision
local PAN_SPEED = 1.0
local SNAP_ON_PAUSE = false -- Snap camera when pausing (disabled for free panning)

-- Global variables for retained mode (not local)
isVisible = isVisible or true
viewportX = viewportX or 0 -- Camera position (horizontal)
viewportY = viewportY or 0 -- Camera position (vertical)
zoom = zoom or DEFAULT_ZOOM
isDragging = isDragging or false
dragStartX = dragStartX or 0
dragStartY = dragStartY or 0
lastMouseX = lastMouseX or 0
lastMouseY = lastMouseY or 0

-- External APIs with fallbacks (Lua 5.4 compatible)
local draw = (_G and _G.draw) or nil
local globals = (_G and _G.globals) or nil
local input = (_G and _G.input) or nil

-- Key constants (Lua 5.4 compatible)
local MOUSE_LEFT = (_G and _G.MOUSE_LEFT) or 107
local MOUSE_WHEEL_UP = (_G and _G.MOUSE_WHEEL_UP) or 112
local MOUSE_WHEEL_DOWN = (_G and _G.MOUSE_WHEEL_DOWN) or 113

-- Font (global for retained mode)
bodyFont = bodyFont or nil

-- Click state (global for retained mode)
clickState = clickState or {}

-- Private helpers --------------------

-- Safe coordinate conversion for drawing API
local function safeCoord(value)
	-- Handle NaN, infinity, and nil
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end

	-- Convert to integer and clamp to reasonable screen bounds
	local coord = math.floor(value + 0.5)
	return math.max(-10000, math.min(10000, coord))
end

-- Safe rectangle drawing with bounds checking
local function safeFilledRect(x1, y1, x2, y2)
	if not draw or not draw.FilledRect then
		return
	end

	local sx1 = safeCoord(x1)
	local sy1 = safeCoord(y1)
	local sx2 = safeCoord(x2)
	local sy2 = safeCoord(y2)

	-- Ensure x1 <= x2 and y1 <= y2
	if sx1 > sx2 then
		sx1, sx2 = sx2, sx1
	end
	if sy1 > sy2 then
		sy1, sy2 = sy2, sy1
	end

	-- Only draw if dimensions are reasonable
	if (sx2 - sx1) > 0 and (sy2 - sy1) > 0 and (sx2 - sx1) < 10000 and (sy2 - sy1) < 10000 then
		draw.FilledRect(sx1, sy1, sx2, sy2)
	end
end

local function initializeFont()
	if not bodyFont and draw and draw.CreateFont then
		-- Create a large, crisp, readable font for body text
		bodyFont = draw.CreateFont("Verdana", 18, 900) -- Much larger and very bold
	end
end

local function getTime()
	return (globals and globals.RealTime) and globals.RealTime() or 0
end

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

-- Convert time to screen position with proper viewport handling
local function timeToScreen(time, startTime, timeRange, screenWidth)
	-- Safety checks for division by zero and invalid inputs
	if not time or not startTime or not timeRange or not screenWidth then
		return 0
	end

	if timeRange <= 0 or screenWidth <= 0 then
		return 0
	end

	-- Check for NaN or infinity inputs
	if time ~= time or startTime ~= startTime or time == math.huge or time == -math.huge then
		return 0
	end

	-- Calculate time position with zoom and viewport offset
	local normalizedTime = (time - startTime) / timeRange
	if normalizedTime ~= normalizedTime then -- Check for NaN
		return 0
	end

	-- Apply zoom and viewport - viewport shifts the view horizontally
	local basePosition = normalizedTime * screenWidth * zoom
	local result = basePosition - viewportX

	-- Guard against extreme values
	if result ~= result or result > 1e9 or result < -1e9 then
		return 0
	end

	return safeCoord(result)
end

-- Convert screen position to time (Lua 5.4 enhanced with safety)
local function screenToTime(screenX, startTime, timeRange, screenWidth)
	-- Safety checks for division by zero and invalid inputs
	if not screenX or not startTime or not timeRange or not screenWidth then
		return startTime or 0
	end

	if screenWidth <= 0 or timeRange <= 0 then
		return startTime
	end

	-- Check for NaN or infinity inputs
	if screenX ~= screenX or startTime ~= startTime or screenX == math.huge or screenX == -math.huge then
		return startTime
	end

	-- Safe division and bounds checking
	local denom = (screenWidth * zoom)
	if denom == 0 or denom ~= denom or denom == math.huge or denom == -math.huge then
		return startTime
	end
	local normalizedX = (screenX + viewportX) / denom
	if normalizedX ~= normalizedX then -- Check for NaN
		return startTime
	end

	local result = startTime + (normalizedX * timeRange)

	-- Final safety check before returning
	if result ~= result or result == math.huge or result == -math.huge then
		return startTime
	end

	return result
end

-- Get color for function based on name hash
local function getFunctionColor(name)
	local hash = 0
	for i = 1, #name do
		hash = hash + string.byte(name, i)
	end
	local r = (hash * 73) % 200 + 55
	local g = (hash * 151) % 200 + 55
	local b = (hash * 211) % 200 + 55
	return r, g, b
end

-- Get thread color based on type
local function getThreadColor(threadType)
	if threadType == "main" then
		return 100, 150, 200 -- Blue for main timeline
	elseif threadType == "custom" then
		return 150, 100, 200 -- Purple for custom threads
	elseif threadType == "script" then
		return 100, 200, 150 -- Green for script timelines
	else
		return 120, 120, 120 -- Gray for unknown
	end
end

-- Draw a function bar with script name
local function drawFunctionBar(func, y, depth, startTime, timeRange, screenWidth, threadType)
	if not func.startTime or not func.endTime then
		return
	end

	local duration = func.endTime - func.startTime
	-- Always show bars even for very fast functions
	if duration < 0 then
		duration = 0.001 -- Minimum 1ms for visibility
	end

	local x1 = timeToScreen(func.startTime, startTime, timeRange, screenWidth)
	local x2 = timeToScreen(func.endTime, startTime, timeRange, screenWidth)
	local calculatedWidth = x2 - x1
	-- Show exact time usage, no artificial minimum width
	local width = calculatedWidth

	-- Skip if completely out of view (but debug why)
	if x2 < 0 or x1 > screenWidth then
		print(
			string.format(
				"⚠️ Function %s SKIPPED: x1=%.0f, x2=%.0f, screenWidth=%d (out of view)",
				func.name or "unnamed",
				x1,
				x2,
				screenWidth
			)
		)
		return
	end

	-- Calculate position with nesting indent
	local indentedY = y + depth * NESTING_INDENT
	local barHeight = THREAD_HEIGHT - 4

	-- Get function color
	local r, g, b = getFunctionColor(func.name or func.key or "unknown")

	-- Draw function bar
	if draw then
		-- Optional debug (guarded)
		if G and G.DEBUG then
			if not _barDebugCount then
				_barDebugCount = 0
			end
			_barDebugCount = _barDebugCount + 1
			if _barDebugCount <= 3 then
				print(
					string.format(
						"🎨 Drawing bar: %s at x1=%.0f, width=%.0f, y=%.0f",
						func.name or "unnamed",
						x1,
						width,
						indentedY
					)
				)
			end
		end

		draw.Color(r, g, b, 180)
		safeFilledRect(x1, indentedY, x1 + width, indentedY + barHeight)

		-- Draw border
		draw.Color(255, 255, 255, 100)
		draw.OutlinedRect(
			math.floor(x1),
			math.floor(indentedY),
			math.floor(x1 + width),
			math.floor(indentedY + barHeight)
		)

		-- Script name is already shown in the green header, no need to repeat it on each function

		-- Draw text if bar is wide enough (check actual text width)
		local name = func.name or func.key or "unknown"
		local nameWidth = 0
		if draw.GetTextSize then
			nameWidth = draw.GetTextSize(name)[1] or 0
		else
			-- Fallback estimate: ~8 pixels per character
			nameWidth = #name * 8
		end

		if width > (nameWidth + 16) then -- Need space for text + padding
			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(x1 + 8), math.floor(indentedY + 4), name)

			-- Show duration if there's additional space
			local durationMs = duration * 1000
			local timeText = string.format("%.1fms", durationMs)
			local timeWidth = 0
			if draw.GetTextSize then
				timeWidth = draw.GetTextSize(timeText)[1] or 0
			else
				timeWidth = #timeText * 8
			end

			if width > (nameWidth + timeWidth + 24) then -- Space for both texts
				draw.Color(255, 255, 100, 255) -- Yellow for visibility
				draw.Text(math.floor(x1 + 8), math.floor(indentedY + 22), timeText)
			end
		elseif width > 20 then
			-- Very narrow bar - just show first few characters
			local shortName = string.sub(name, 1, math.max(1, math.floor(width / 8) - 1))
			draw.Color(255, 255, 255, 200)
			draw.Text(math.floor(x1 + 2), math.floor(indentedY + 4), shortName)
		end
	end

	return indentedY + barHeight + 2
end

-- Check if two functions overlap in time
local function functionsOverlap(func1, func2)
	if not func1.startTime or not func1.endTime or not func2.startTime or not func2.endTime then
		return false
	end
	local overlap = not (func1.endTime <= func2.startTime or func2.endTime <= func1.startTime)
	if overlap then
		print(
			string.format(
				"⚠️ OVERLAP: %s (%.3f-%.3f) vs %s (%.3f-%.3f)",
				func1.name or "unnamed",
				func1.startTime,
				func1.endTime,
				func2.name or "unnamed",
				func2.startTime,
				func2.endTime
			)
		)
	end
	return overlap
end

-- Draw function hierarchy with proper stacking for overlapping functions
local function drawFunctionHierarchy(functions, baseY, startTime, timeRange, screenWidth, threadType)
	local currentY = baseY
	local stackLevels = {} -- Track which Y levels are occupied by time ranges

	print(
		string.format("🎨 Drawing hierarchy: %d functions, baseY=%.0f, timeRange=%.3f", #functions, baseY, timeRange)
	)

	for i, func in ipairs(functions) do
		-- Find the appropriate Y level for this function
		local level = 0
		local foundLevel = false

		-- Check existing stack levels for conflicts
		while not foundLevel do
			local conflictFound = false
			for _, occupiedFunc in ipairs(stackLevels[level] or {}) do
				if functionsOverlap(func, occupiedFunc) then
					conflictFound = true
					break
				end
			end

			if not conflictFound then
				-- This level is free, use it
				if not stackLevels[level] then
					stackLevels[level] = {}
				end
				table.insert(stackLevels[level], func)
				foundLevel = true
			else
				-- Try next level
				level = level + 1
			end
		end

		-- Draw this function at the determined level
		local functionY = baseY + (level * (THREAD_HEIGHT + THREAD_SPACING))
		print(
			string.format("  Drawing function %d: %s at level %d, Y=%.0f", i, func.name or "unnamed", level, functionY)
		)
		local newY = drawFunctionBar(func, functionY, 0, startTime, timeRange, screenWidth, threadType)

		-- Update currentY to track the maximum used Y
		currentY = math.max(currentY, functionY + THREAD_HEIGHT + THREAD_SPACING)

		-- Draw children with indentation (children get their own stacking context)
		if func.children and #func.children > 0 then
			local childrenY =
				drawFunctionHierarchy(func.children, currentY, startTime, timeRange, screenWidth, threadType)
			currentY = math.max(currentY, childrenY)
		end
	end

	return currentY
end

-- Draw a thread
local function drawThread(thread, y, startTime, timeRange, screenWidth)
	if not draw then
		return y
	end

	local threadType = thread.type or "main"
	local r, g, b = getThreadColor(threadType)

	-- Draw thread header
	draw.Color(r, g, b, 200)
	safeFilledRect(0, y, screenWidth, y + HEADER_HEIGHT)

	-- Draw thread border
	draw.Color(255, 255, 255, 150)
	draw.OutlinedRect(0, math.floor(y), screenWidth, math.floor(y + HEADER_HEIGHT))

	-- Draw thread name
	draw.Color(255, 255, 255, 255)
	local threadName = thread.name or "Main Timeline"
	draw.Text(6, math.floor(y + 4), threadName)

	-- ALWAYS show thread info even if no duration/memory
	local functionCount = (thread.functions and #thread.functions) or 0
	local infoText = string.format("(%d functions)", functionCount)
	if thread.duration then
		local durationMs = thread.duration * 1000
		infoText = string.format("%.2fms | %s", durationMs, infoText)
		if thread.memDelta then
			infoText = infoText .. string.format(" | %.1fKB", thread.memDelta)
		end
	end
	draw.Color(220, 220, 220, 255)
	draw.Text(150, math.floor(y + 4), infoText)

	local contentY = y + HEADER_HEIGHT + 2

	-- Draw function hierarchy
	if thread.functions and #thread.functions > 0 then
		contentY = drawFunctionHierarchy(thread.functions, contentY, startTime, timeRange, screenWidth, threadType)
	end

	return contentY + THREAD_SPACING * 2
end

-- Handle input (ALWAYS active when body is visible and paused)
local function handleInput(screenWidth, screenHeight, topBarHeight)
	-- FORCE input to work - don't check for input existence
	if not _G.input or not _G.input.GetMousePos then
		return
	end

	local pos = _G.input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Only handle input in body area (below top bar)
	if my < topBarHeight then
		return
	end

	-- Adjust mouse position for body area
	local bodyMy = my - topBarHeight

	-- Handle dragging - FORCE detection
	local currentlyDragging = _G.input.IsButtonDown and _G.input.IsButtonDown(MOUSE_LEFT)
	local wasDragging = clickState["drag_active"] or false

	if currentlyDragging and not wasDragging then
		-- Start drag
		clickState["drag_active"] = true
		isDragging = true
		dragStartX = mx
		dragStartY = bodyMy
		lastMouseX = mx
		lastMouseY = bodyMy
		print(string.format("🎯 DRAG START: mx=%d, my=%d", mx, bodyMy))
	elseif currentlyDragging and isDragging then
		-- Continue drag - apply both X and Y movement
		local deltaX = mx - lastMouseX
		local deltaY = bodyMy - lastMouseY

		if math.abs(deltaX) > 1 or math.abs(deltaY) > 1 then -- Require minimum movement
			viewportX = viewportX - deltaX * PAN_SPEED
			viewportY = viewportY - deltaY * PAN_SPEED
			print(
				string.format(
					"🎯 DRAGGING: deltaX=%d, deltaY=%d, viewportX=%.1f, viewportY=%.1f",
					deltaX,
					deltaY,
					viewportX,
					viewportY
				)
			)
		end

		lastMouseX = mx
		lastMouseY = bodyMy
	elseif not currentlyDragging and wasDragging then
		-- Release drag
		clickState["drag_active"] = false
		isDragging = false
		print("🎯 DRAG END")
	end

	-- Handle zoom with MOUSE WHEEL - FORCE detection
	if _G.input.IsButtonDown then
		local wheelUpNow = _G.input.IsButtonDown(112)
		local wheelDownNow = _G.input.IsButtonDown(113)

		if wheelUpNow and not clickState["wheel_up"] then
			local oldZoom = zoom
			zoom = clamp(zoom * 1.2, MIN_ZOOM, MAX_ZOOM)
			clickState["wheel_up"] = true
			print(string.format("🎯 ZOOM IN: %.3f -> %.3f", oldZoom, zoom))
		elseif not wheelUpNow and clickState["wheel_up"] then
			clickState["wheel_up"] = false
		end

		if wheelDownNow and not clickState["wheel_down"] then
			local oldZoom = zoom
			zoom = clamp(zoom / 1.2, MIN_ZOOM, MAX_ZOOM)
			clickState["wheel_down"] = true
			print(string.format("🎯 ZOOM OUT: %.3f -> %.3f", oldZoom, zoom))
		elseif not wheelDownNow and clickState["wheel_down"] then
			clickState["wheel_down"] = false
		end
	end
end

-- Public API -------------------------

function UIBody.Initialize()
	initializeFont()
	isVisible = true
	viewportX = 0
	viewportY = 0
	zoom = DEFAULT_ZOOM
	isDragging = false
end

function UIBody.SetVisible(visible)
	isVisible = visible
end

function UIBody.IsVisible()
	return isVisible
end

function UIBody.ToggleVisible()
	isVisible = not isVisible
	return isVisible
end

function UIBody.Draw(profilerData, topBarHeight)
	if not isVisible or not draw or not profilerData then
		return
	end

	local screenW, screenH = draw.GetScreenSize()
	local bodyHeight = screenH - topBarHeight

	-- Set font
	if bodyFont and draw.SetFont then
		draw.SetFont(bodyFont)
	end

	-- Trigger stats debug output (every 5s) only when DEBUG
	local MicroProfiler = require("Profiler.microprofiler")
	if G and G.DEBUG then
		MicroProfiler.GetStats()
	end

	-- Draw body background
	draw.Color(25, 25, 25, 220)
	safeFilledRect(0, topBarHeight, screenW, screenH)

	-- FIXED TIME WINDOW: constant 5 seconds for body navigation
	local currentTime = getTime()
	local timeWindow = 5.0 / zoom -- 5-second window scaled by zoom

	-- When paused, freeze the timeline scope
	if not frozenTimeScope then
		frozenTimeScope = {}
	end

	local isPaused = false
	-- Check if paused from UI
	local UITop = require("Profiler.ui_top")
	if UITop and UITop.IsPaused then
		isPaused = UITop.IsPaused()
	end

	-- Detect pause transitions for snapping
	if _wasPaused == nil then
		_wasPaused = isPaused
	end

	local startTime, endTime, timeRange
	if isPaused then
		-- PAUSED: Use frozen scope + user navigation
		if not frozenTimeScope.center then
			-- Auto-center on middle of all recorded data (not just latest)
			local earliest, latest = math.huge, -math.huge
			if profilerData.scriptTimelines then
				for _, scriptData in pairs(profilerData.scriptTimelines) do
					if scriptData.functions then
						for _, func in ipairs(scriptData.functions) do
							if func.startTime and func.endTime then
								earliest = math.min(earliest, func.startTime)
								latest = math.max(latest, func.endTime)
							end
						end
					end
				end
			end
			if earliest ~= math.huge and latest ~= -math.huge then
				frozenTimeScope.center = (earliest + latest) / 2 -- Center on middle of data
			else
				frozenTimeScope.center = currentTime -- Fallback
			end
		end
		-- If a frame is selected in top bar, center on frozen scope; horizontal navigation handled by viewportX in timeToScreen
		local centerTime = frozenTimeScope.center
		local halfWindow = timeWindow / 2
		startTime = centerTime - halfWindow
		endTime = centerTime + halfWindow
		timeRange = timeWindow

		-- Snap on transition to paused
		if SNAP_ON_PAUSE and (not _wasPaused and isPaused) then
			-- Calculate bounds and snap horizontally to nearest function start
			local function getDataTimeBounds()
				local earliest, latest = math.huge, -math.huge
				local function consider(node)
					if node.startTime and node.endTime then
						earliest = math.min(earliest, node.startTime)
						latest = math.max(latest, node.endTime)
					end
				end
				if profilerData.scriptTimelines then
					for _, scriptData in pairs(profilerData.scriptTimelines) do
						if scriptData.functions then
							for _, f in ipairs(scriptData.functions) do
								consider(f)
							end
						end
					end
				end
				if profilerData.mainTimeline then
					for _, f in ipairs(profilerData.mainTimeline) do
						consider(f)
					end
				end
				return earliest, latest
			end

			local earliest, latest = getDataTimeBounds()
			if earliest ~= math.huge and latest ~= -math.huge then
				-- Find nearest record start to centerTime
				local nearest = centerTime
				local bestDist = math.huge
				local function checkNearest(list)
					for _, f in ipairs(list) do
						if f.startTime then
							local d = math.abs(f.startTime - centerTime)
							if d < bestDist then
								bestDist = d
								nearest = f.startTime
							end
						end
					end
				end
				if profilerData.scriptTimelines then
					for _, scriptData in pairs(profilerData.scriptTimelines) do
						if scriptData.functions then
							checkNearest(scriptData.functions)
						end
					end
				end
				if profilerData.mainTimeline then
					checkNearest(profilerData.mainTimeline)
				end

				-- Convert desired time shift into viewportX shift so that window centers on nearest
				local desiredShift = nearest - centerTime -- seconds
				local pixelsPerWindow = (screenW * zoom)
				local px = (desiredShift / timeRange) * pixelsPerWindow
				viewportX = viewportX - px -- apply shift via viewport mapping
			end

			-- Snap vertically to top
			viewportY = 0
		end
	else
		-- RUNNING: Follow current time (moving timeline)
		frozenTimeScope.center = nil -- Clear frozen scope
		local halfWindow = timeWindow / 2
		startTime = currentTime - halfWindow
		endTime = currentTime + halfWindow
		timeRange = timeWindow
	end

	-- Track pause state for next frame
	_wasPaused = isPaused

	-- Reduced debug spam
	if isPaused and not _timeDebugCount then
		_timeDebugCount = 0
	end
	if isPaused then
		_timeDebugCount = _timeDebugCount + 1
		if _timeDebugCount > 120 then -- Show every 2 seconds
			_timeDebugCount = 0
			print(
				string.format(
					"🕒 Time window: %.3fs - %.3fs (%.3fs range, zoom: %.2fx)",
					startTime,
					endTime,
					timeRange,
					zoom
				)
			)
		end
	end

	-- Viewport bounds: clamp to available content/time
	if viewportX ~= viewportX or viewportX == math.huge or viewportX == -math.huge then
		viewportX = 0
	end
	if viewportY ~= viewportY or viewportY == math.huge or viewportY == -math.huge then
		viewportY = 0
	end

	-- Calculate actual rendered content height (match the drawing logic)
	local simulatedY = topBarHeight + 10 - viewportY -- Same as currentY calculation
	local actualContentBottom = simulatedY

	-- Simulate drawing to find actual bottom
	if profilerData.scriptTimelines then
		for scriptName, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions then
				-- Each script adds: header + functions + spacing
				actualContentBottom = actualContentBottom + HEADER_HEIGHT + 2
				actualContentBottom = actualContentBottom + (#scriptData.functions * (THREAD_HEIGHT + THREAD_SPACING))
				actualContentBottom = actualContentBottom + THREAD_SPACING * 2
			end
		end
	end

	-- Add main timeline
	if profilerData.mainTimeline and #profilerData.mainTimeline > 0 then
		actualContentBottom = actualContentBottom
			+ HEADER_HEIGHT
			+ (#profilerData.mainTimeline * (THREAD_HEIGHT + THREAD_SPACING))
			+ 20
	end

	-- Add custom threads
	if profilerData.customThreads then
		for _, thread in ipairs(profilerData.customThreads) do
			if thread.children and #thread.children > 0 then
				actualContentBottom = actualContentBottom
					+ HEADER_HEIGHT
					+ (#thread.children * (THREAD_HEIGHT + THREAD_SPACING))
					+ 20
			end
		end
	end

	-- Calculate proper viewportY limits (only clamp when running)
	local bodyHeight = screenH - topBarHeight
	local contentHeight = actualContentBottom - (topBarHeight + 10) -- Remove initial offset
	local maxViewportY = math.max(0, contentHeight - bodyHeight + 20) -- Add small buffer
	if not isPaused then
		viewportY = clamp(viewportY, 0, maxViewportY)
	end

	-- Horizontal clamping is disabled when paused so panning remains free

	local currentY = topBarHeight + 10 - viewportY

	-- Draw script timelines (separate stacks per script) - FORCE DISPLAY
	if profilerData.scriptTimelines then
		for scriptName, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions then
				local scriptThread = {
					name = "Script: " .. scriptName,
					type = "script",
					functions = scriptData.functions,
					duration = timeRange,
				}
				-- DEBUG: Always show function count and time ranges
				print(
					string.format("📊 Drawing script timeline: %s (%d functions)", scriptName, #scriptData.functions)
				)
				for i, func in ipairs(scriptData.functions) do
					if i <= 3 then -- Show first 3 functions
						print(
							string.format(
								"  Function %d: %s (%.3f-%.3f, duration: %.3fms)",
								i,
								func.name or "unnamed",
								func.startTime or 0,
								func.endTime or 0,
								(func.duration or 0) * 1000
							)
						)
					end
				end

				-- ALWAYS draw the thread header even if no functions yet
				currentY = drawThread(scriptThread, currentY, startTime, timeRange, screenW)
			end
		end
	else
		-- Show debug info if no script timelines
		draw.Color(255, 255, 0, 255)
		draw.Text(10, currentY, "⚠️ No script timelines found")
		currentY = currentY + 25
	end

	-- Draw main timeline thread (fallback/combined view)
	if profilerData.mainTimeline and #profilerData.mainTimeline > 0 then
		local mainThread = {
			name = "All Scripts (Combined)",
			type = "main",
			functions = profilerData.mainTimeline,
			duration = timeRange,
		}
		currentY = drawThread(mainThread, currentY, startTime, timeRange, screenW)
	end

	-- Draw custom threads (manual profiling)
	if profilerData.customThreads then
		for _, thread in ipairs(profilerData.customThreads) do
			if thread.children and #thread.children > 0 then
				local customThread = {
					name = "Custom: " .. (thread.name or "Unnamed"),
					type = "custom",
					functions = thread.children,
					duration = thread.duration,
					memDelta = thread.memDelta,
				}
				currentY = drawThread(customThread, currentY, startTime, timeRange, screenW)
			end
		end
	end

	-- ALWAYS draw zoom and pan info (READABLE - integer coordinates)
	draw.Color(255, 255, 255, 255) -- Bright white
	draw.Text(
		10,
		screenH - 90,
		string.format("Zoom: %.2fx (Window: %.3fs) %s", zoom, timeWindow, isPaused and "[FROZEN]" or "[LIVE]")
	)
	draw.Text(10, screenH - 75, string.format("Pan: X=%.0f Y=%.0f", viewportX, viewportY))
	draw.Text(10, screenH - 60, string.format("Time: %.3fs - %.3fs", startTime, endTime))
	draw.Text(10, screenH - 45, "Drag=Pan, Wheel=Zoom, P=Pause")

	-- Debug input state
	local mousePos = (_G.input and _G.input.GetMousePos) and _G.input.GetMousePos() or { 0, 0 }
	local mouseDown = (_G.input and _G.input.IsButtonDown) and _G.input.IsButtonDown(MOUSE_LEFT) or false
	draw.Text(
		10,
		screenH - 30,
		string.format(
			"Mouse: %d,%d Down:%s Drag:%s",
			mousePos[1] or 0,
			mousePos[2] or 0,
			tostring(mouseDown),
			tostring(isDragging)
		)
	)
	draw.Text(10, screenH - 15, string.format("Input API: %s", (_G.input and "OK") or "MISSING"))

	-- DEBUG: Show data status
	local totalFunctions = 0
	if profilerData.scriptTimelines then
		for _, scriptData in pairs(profilerData.scriptTimelines) do
			totalFunctions = totalFunctions + #scriptData.functions
		end
	end
	if profilerData.mainTimeline then
		totalFunctions = totalFunctions + #profilerData.mainTimeline
	end
	if profilerData.customThreads then
		totalFunctions = totalFunctions + #profilerData.customThreads
	end

	-- Count script timelines
	local scriptCount = 0
	if profilerData.scriptTimelines then
		for _ in pairs(profilerData.scriptTimelines) do
			scriptCount = scriptCount + 1
		end
	end

	draw.Color(255, 255, 0, 255)
	draw.Text(10, screenH - 10, string.format("Data: %d functions, %d scripts", totalFunctions, scriptCount))

	-- Handle input
	handleInput(screenW, screenH, topBarHeight)
end

function UIBody.ResetCamera()
	viewportX = 0
	viewportY = 0
	zoom = DEFAULT_ZOOM
end

function UIBody.SetZoom(newZoom)
	zoom = clamp(newZoom, MIN_ZOOM, MAX_ZOOM)
end

function UIBody.GetZoom()
	return zoom
end

function UIBody.SetViewport(x, y)
	viewportX = x
	viewportY = y
end

function UIBody.GetViewport()
	return viewportX, viewportY
end

-- Center the timeline on a specific global timestamp (called from top bar)
function UIBody.CenterOnTimestamp(timestamp)
	if not timestamp then
		return
	end
	-- Set frozen center and reset pan for precise jump
	if not frozenTimeScope then
		frozenTimeScope = {}
	end
	frozenTimeScope.center = timestamp
	viewportX = 0
end

return UIBody
