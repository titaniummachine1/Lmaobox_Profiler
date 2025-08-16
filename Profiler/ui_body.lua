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
local SNAP_ON_PAUSE = true -- Snap camera when pausing

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

-- Convert time to screen position (Lua 5.4 enhanced with safety)
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

	-- Safe division and bounds checking
	local normalizedTime = (time - startTime) / timeRange
	if normalizedTime ~= normalizedTime then -- Check for NaN
		return 0
	end

	local result = (normalizedTime * screenWidth * zoom) - viewportX

	-- Final safety check before returning
	if result ~= result or result == math.huge or result == -math.huge then
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
	local normalizedX = (screenX + viewportX) / (screenWidth * zoom)
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
	local width = math.max(50, calculatedWidth) -- Minimum 50px width for visibility

	-- Skip if completely out of view
	if x2 < 0 or x1 > screenWidth then
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

		-- Draw script name on the left (always visible, fixed position)
		if func.scriptName and depth == 0 then
			local scriptText = "[" .. func.scriptName .. "]"
			draw.Color(255, 255, 255, 255) -- Bright white for maximum visibility
			-- Use integer coordinates to prevent sub-pixel rendering blur
			draw.Text(5, math.floor(indentedY + 6), scriptText)
		end

		-- Draw text if bar is wide enough (LARGE READABLE TEXT)
		if width > 50 then -- Increase minimum width due to larger font
			local name = func.name or func.key or "unknown"
			if #name > 12 then -- Shorter names due to larger font
				name = string.sub(name, 1, 9) .. "..."
			end

			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(x1 + 8), math.floor(indentedY + 4), name)

			-- Show duration (more compact)
			if width > 100 then -- Increase width requirement for duration
				local durationMs = duration * 1000
				local timeText = string.format("%.1fms", durationMs)
				draw.Color(255, 255, 100, 255) -- Yellow for visibility
				draw.Text(math.floor(x1 + 8), math.floor(indentedY + 22), timeText)
			end
		end
	end

	return indentedY + barHeight + 2
end

-- Draw function hierarchy recursively
local function drawFunctionHierarchy(functions, baseY, startTime, timeRange, screenWidth, threadType)
	local currentY = baseY

	for _, func in ipairs(functions) do
		-- Draw this function
		local newY = drawFunctionBar(func, currentY, 0, startTime, timeRange, screenWidth, threadType)
		if newY then
			currentY = newY
		end

		-- Draw children with indentation
		if func.children and #func.children > 0 then
			currentY = drawFunctionHierarchy(func.children, currentY, startTime, timeRange, screenWidth, threadType)
		end

		currentY = currentY + THREAD_SPACING
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

-- Handle input
local function handleInput(screenWidth, screenHeight, topBarHeight)
	if not input or not input.GetMousePos then
		return
	end

	local pos = input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Only handle input in body area (below top bar)
	if my < topBarHeight then
		return
	end

	-- Adjust mouse position for body area
	local bodyMy = my - topBarHeight

	-- Handle dragging (smart detection)
	local currentlyDragging = input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)
	local wasDragging = clickState["drag_active"] or false

	if currentlyDragging and not wasDragging then
		-- Start drag (either click or sudden hold)
		clickState["drag_active"] = true
		isDragging = true
		dragStartX = mx
		dragStartY = bodyMy
		lastMouseX = mx
		lastMouseY = bodyMy
	elseif currentlyDragging and isDragging then
		-- Continue drag - apply both X and Y movement
		local deltaX = mx - lastMouseX
		local deltaY = bodyMy - lastMouseY

		if math.abs(deltaX) > 0 or math.abs(deltaY) > 0 then
			viewportX = viewportX - deltaX * PAN_SPEED
			viewportY = viewportY - deltaY * PAN_SPEED
		end

		lastMouseX = mx
		lastMouseY = bodyMy
	elseif not currentlyDragging and wasDragging then
		-- Release drag
		clickState["drag_active"] = false
		isDragging = false
	end

	-- Handle zoom with MOUSE WHEEL (112=up, 113=down)
	if input.IsButtonDown then
		-- Zoom in (scroll up = 112)
		local wheelUpNow = input.IsButtonDown(112)
		local wheelUpWas = clickState["wheel_up"] or false
		if wheelUpNow and not wheelUpWas then
			zoom = clamp(zoom * 1.5, MIN_ZOOM, MAX_ZOOM)
			clickState["wheel_up"] = true
		elseif not wheelUpNow and wheelUpWas then
			clickState["wheel_up"] = false
		end

		-- Zoom out (scroll down = 113)
		local wheelDownNow = input.IsButtonDown(113)
		local wheelDownWas = clickState["wheel_down"] or false
		if wheelDownNow and not wheelDownWas then
			zoom = clamp(zoom / 1.5, MIN_ZOOM, MAX_ZOOM)
			clickState["wheel_down"] = true
		elseif not wheelDownNow and wheelDownWas then
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

	-- FIXED TIMELINE: Don't move when paused!
	local currentTime = getTime()
	local timeWindow = 10.0 / zoom -- Time window controlled by zoom

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
			-- Auto-center on most recent recorded data
			local latestTime = currentTime
			if profilerData.scriptTimelines then
				for _, scriptData in pairs(profilerData.scriptTimelines) do
					if scriptData.functions then
						for _, func in ipairs(scriptData.functions) do
							if func.endTime and func.endTime > latestTime then
								latestTime = func.endTime
							end
						end
					end
				end
			end
			frozenTimeScope.center = latestTime -- Start at latest recorded data
		end
		-- If a frame is selected in top bar, jump to that time
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

	-- DEBUG: Show time window info - ONLY when not paused to prevent spam
	if (G and G.DEBUG) and not isPaused then
		if not _timeWindowDebugCount then
			_timeWindowDebugCount = 0
		end
		_timeWindowDebugCount = _timeWindowDebugCount + 1

		if _timeWindowDebugCount == 60 then -- Show every 60 frames (once per second at 60fps)
			_timeWindowDebugCount = 0
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

	-- Determine vertical bounds dynamically based on content height
	local contentHeight = 0
	if profilerData and profilerData.scriptTimelines then
		local scriptCount = 0
		for _, scriptData in pairs(profilerData.scriptTimelines) do
			scriptCount = scriptCount + 1
			if scriptData.functions and #scriptData.functions > 0 then
				contentHeight = contentHeight
					+ HEADER_HEIGHT
					+ (#scriptData.functions * (THREAD_HEIGHT + THREAD_SPACING))
					+ 20
			else
				contentHeight = contentHeight + HEADER_HEIGHT + 20
			end
		end
		if scriptCount == 0 and profilerData.mainTimeline then
			contentHeight = contentHeight
				+ HEADER_HEIGHT
				+ (#profilerData.mainTimeline * (THREAD_HEIGHT + THREAD_SPACING))
				+ 20
		end
	end

	-- Clamp viewportY to content bounds (fix inverted/overscroll)
	local bodyHeight = screenH - topBarHeight
	local maxViewportY = math.max(0, contentHeight - bodyHeight)
	viewportY = clamp(viewportY, 0, maxViewportY)

	-- Horizontal clamping when paused to data time range
	if isPaused then
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

		if earliest ~= math.huge and latest ~= -math.huge then
			-- Compute allowable viewportX range so the visible window [startTime,endTime] stays within [earliest,latest]
			local pixelsPerWindow = (screenW * zoom)
			local minViewportX = ((earliest - startTime) / timeRange) * pixelsPerWindow
			local maxViewportX = ((latest - endTime) / timeRange) * pixelsPerWindow
			if minViewportX > maxViewportX then
				minViewportX, maxViewportX = maxViewportX, minViewportX
			end
			viewportX = clamp(viewportX, minViewportX, maxViewportX)
		end
	end

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
				-- ALWAYS draw the thread header even if no functions yet
				currentY = drawThread(scriptThread, currentY, startTime, timeRange, screenW)
				if G and G.DEBUG then
					print(
						string.format(
							"📊 Drawing script timeline: %s (%d functions)",
							scriptName,
							#scriptData.functions
						)
					)
				end
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

	-- Draw zoom and pan info (READABLE - integer coordinates)
	draw.Color(255, 255, 255, 200)
	draw.Text(
		10,
		screenH - 70,
		string.format("Zoom: %.2fx (Window: %.3fs) %s", zoom, timeWindow, isPaused and "[FROZEN]" or "[LIVE]")
	)
	draw.Text(10, screenH - 55, string.format("Pan: X=%.0f Y=%.0f", viewportX, viewportY))
	draw.Text(10, screenH - 40, string.format("Time: %.3fs - %.3fs", startTime, endTime))
	draw.Text(10, screenH - 25, "Q/E=Zoom, Drag=Pan, P=Pause")

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

return UIBody
