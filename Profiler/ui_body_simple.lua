--[[
    Simple UI Body Module - Virtual Profiler Board
    All elements positioned on fixed coordinate system, then board is transformed
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]

-- Module declaration
local UIBody = {}

-- Constants
local BOARD_WIDTH = 2000 -- Virtual board width in pixels
local BOARD_HEIGHT = 2000 -- Virtual board height in pixels
local FUNCTION_HEIGHT = 20 -- Height of each function bar
local FUNCTION_SPACING = 2 -- Spacing between function levels
local SCRIPT_HEADER_HEIGHT = 25 -- Height of script headers
local SCRIPT_SPACING = 10 -- Spacing between scripts
local TIME_SCALE = 50000 -- Pixels per second (horizontal scale) - makes 1ms = 50px
local RULER_HEIGHT = 30 -- Height of time ruler at top of body
local MEMORY_SCALE_START_MB = 1
local MEMORY_SCALE_END_MB = 10
local MEMORY_HEIGHT_MULTIPLIER_MAX = 2

-- Global state (retained mode)
local boardOffsetX = 0 -- Camera position on virtual board
local boardOffsetY = 0 -- Camera position on virtual board
local boardZoom = 1.0 -- Zoom level of the board
local isDragging = false
local lastMouseX, lastMouseY = 0, 0
local currentTopBarHeight = 60 -- Current top bar height (updated each frame)
local hoveredFunc = nil
local cachedScriptKeys = {}
local cachedScriptCount = 0
local cachedDataStartTime = nil
local cachedDataEndTime = nil
local lastDataUpdateTime = 0
local layoutItems = {}
local levelRanges = {}
local levelHeights = {}
local levelOffsets = {}

-- External APIs
local draw = draw
local input = input
local MOUSE_LEFT = MOUSE_LEFT or 107
local KEY_Q = KEY_Q or 18
local KEY_E = KEY_E or 20

-- globals is a global table provided by the environment (TickInterval, etc.)

-- Helper functions
-- Use os.clock() for microsecond-level timing precision

-- Convert time to board X coordinate
-- startTime is the reference for the current visible window (usually dataStartTime)
local function timeToBoardX(time, startTime)
	return (time - startTime) * TIME_SCALE
end

local function clearArray(array)
	assert(array, "clearArray: array missing")
	for i = #array, 1, -1 do
		array[i] = nil
	end
end

local function getFunctionHeight(func)
	assert(func, "getFunctionHeight: func missing")
	local memDeltaKb = func.memDelta
	assert(type(memDeltaKb) == "number", "getFunctionHeight: memDelta invalid")
	if memDeltaKb < 0 then
		memDeltaKb = 0
	end
	local memDeltaMb = memDeltaKb / 1024
	if memDeltaMb <= MEMORY_SCALE_START_MB then
		return FUNCTION_HEIGHT
	end
	local cappedMb = math.min(memDeltaMb, MEMORY_SCALE_END_MB)
	local ratio = (cappedMb - MEMORY_SCALE_START_MB) / (MEMORY_SCALE_END_MB - MEMORY_SCALE_START_MB)
	local scale = 1 + ratio * (MEMORY_HEIGHT_MULTIPLIER_MAX - 1)
	return FUNCTION_HEIGHT * scale
end

-- Convert board coordinates to screen coordinates
-- X is zoom-scaled, Y is NOT zoom-scaled (fixed vertical layout)
local function boardToScreen(boardX, boardY)
	local screenX = (boardX - boardOffsetX) * boardZoom
	-- Y is in screen pixels, not board units - NO zoom scaling on Y axis
	local screenY = currentTopBarHeight + RULER_HEIGHT + boardY
	return screenX, screenY
end

-- Convert screen coordinates to board coordinates
local function screenToBoard(screenX, screenY)
	local boardX = (screenX / boardZoom) + boardOffsetX
	local boardY = (screenY / boardZoom) + boardOffsetY
	return boardX, boardY
end

-- Draw a function bar on the virtual board
local function drawFunctionOnBoard(func, boardX, boardY, boardWidth, screenW, screenH)
	if not func.startTime or not func.endTime or not draw then
		return
	end

	-- Convert board coordinates to screen coordinates
	local screenX, screenY = boardToScreen(boardX, boardY)
	local screenWidth = boardWidth * boardZoom
	-- Y is NOT zoom-scaled - fixed pixel height
	local screenHeight = FUNCTION_HEIGHT

	-- Clamp screen coordinates to prevent overflow at extreme zoom
	local clampLimit = math.max(100000, boardZoom * 10000)
	local clampedScreenX = math.max(-clampLimit, math.min(clampLimit, screenX))
	local clampedScreenWidth = math.max(0, math.min(clampLimit * 2, screenWidth))

	-- Only draw if visible on screen (use actual screen bounds)
	if
		clampedScreenX + clampedScreenWidth > 0
		and clampedScreenX < screenW
		and screenY + screenHeight > currentTopBarHeight
		and screenY < screenH
	then
		-- Check if mouse is hovering over this function
		local isHovered = false
		if input and input.GetMousePos then
			local pos = input.GetMousePos()
			local mx, my = pos[1] or 0, pos[2] or 0
			if
				mx >= clampedScreenX
				and mx <= clampedScreenX + clampedScreenWidth
				and my >= screenY
				and my <= screenY + screenHeight
			then
				isHovered = true
				hoveredFunc = func
			end
		end

		-- Draw function bar (highlight if hovered)
		if isHovered then
			draw.Color(150, 200, 255, 220)
		else
			draw.Color(100, 150, 200, 180)
		end
		draw.FilledRect(
			math.floor(clampedScreenX),
			math.floor(screenY),
			math.floor(clampedScreenX + clampedScreenWidth),
			math.floor(screenY + screenHeight)
		)

		-- Draw vertical grid lines on function bar (segment by milliseconds)
		local duration = func.endTime - func.startTime
		local gridInterval = 0.001 -- 1ms grid
		if duration > 0.01 then
			local gridStart = math.ceil(func.startTime / gridInterval) * gridInterval
			local gridTime = gridStart
			local gridCount = 0
			while gridTime < func.endTime and gridCount < 100 do
				local gridBoardX = timeToBoardX(gridTime, func.startTime) + boardX
				local gridScreenX, _ = boardToScreen(gridBoardX, 0)

				local clampedGridX = math.max(-clampLimit, math.min(clampLimit, gridScreenX))
				if clampedGridX >= clampedScreenX and clampedGridX <= clampedScreenX + clampedScreenWidth then
					draw.Color(255, 255, 255, 30)
					draw.Line(
						math.floor(clampedGridX),
						math.floor(screenY),
						math.floor(clampedGridX),
						math.floor(screenY + screenHeight)
					)
				end

				gridTime = gridTime + gridInterval
				gridCount = gridCount + 1
			end
		end

		-- Draw border
		draw.Color(255, 255, 255, 100)
		draw.OutlinedRect(
			math.floor(clampedScreenX),
			math.floor(screenY),
			math.floor(clampedScreenX + clampedScreenWidth),
			math.floor(screenY + screenHeight)
		)

		-- Draw function name if it fits (positioned on board, then transformed)
		local name = func.name or "unknown"
		if clampedScreenWidth > 50 and screenHeight > 12 then
			-- Position text on board, then transform to screen
			local textBoardX = boardX + 4
			local textBoardY = boardY + 2
			local textScreenX, textScreenY = boardToScreen(textBoardX, textBoardY)
			local clampedTextX = math.max(-clampLimit, math.min(clampLimit, textScreenX))

			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(clampedTextX), math.floor(textScreenY), name)
		end

		-- Draw duration if there's space (positioned on board, then transformed)
		if clampedScreenWidth > 120 and screenHeight > 24 then
			local durationMs = duration * 1000 -- ms
			local durationText = string.format("%.3fms", durationMs)

			-- Position duration text on board, then transform to screen
			local durationBoardX = boardX + 4
			local durationBoardY = boardY + FUNCTION_HEIGHT - 12
			local durationScreenX, durationScreenY = boardToScreen(durationBoardX, durationBoardY)
			local clampedDurationX = math.max(-clampLimit, math.min(clampLimit, durationScreenX))

			draw.Color(255, 255, 100, 255)
			draw.Text(math.floor(clampedDurationX), math.floor(durationScreenY), durationText)
		end
	end
end

-- Draw a script section on the virtual board
local function drawScriptOnBoard(scriptName, functions, boardY, dataStartTime, dataEndTime, screenW, screenH)
	if not draw then
		return boardY
	end

	-- Calculate script bounds
	local scriptStartTime = math.huge
	local scriptEndTime = -math.huge

	for _, func in ipairs(functions) do
		if func.startTime and func.endTime then
			scriptStartTime = math.min(scriptStartTime, func.startTime)
			scriptEndTime = math.max(scriptEndTime, func.endTime)
		end
	end

	-- Draw script header - FIXED PIXEL HEIGHT (not zoom-scaled)
	if scriptStartTime ~= math.huge and scriptEndTime ~= -math.huge then
		local headerBoardX = timeToBoardX(scriptStartTime, dataStartTime)
		local headerBoardWidth = timeToBoardX(scriptEndTime, dataStartTime) - headerBoardX
		local headerBoardY = boardY

		-- Convert to screen coordinates
		local headerScreenX, headerScreenY = boardToScreen(headerBoardX, headerBoardY)
		local headerScreenWidth = headerBoardWidth * boardZoom
		local headerScreenHeight = SCRIPT_HEADER_HEIGHT -- Fixed pixel height, no zoom

		-- Only draw if visible (check both horizontal and vertical bounds)
		if
			headerScreenX + headerScreenWidth > 0
			and headerScreenX < screenW
			and headerScreenY + headerScreenHeight > currentTopBarHeight
			and headerScreenY < screenH
		then
			-- Draw header background (all coordinates from board transform)
			draw.Color(60, 120, 60, 200)
			draw.FilledRect(
				math.floor(headerScreenX),
				math.floor(headerScreenY),
				math.floor(headerScreenX + headerScreenWidth),
				math.floor(headerScreenY + headerScreenHeight)
			)

			-- Draw header border (all coordinates from board transform)
			draw.Color(255, 255, 255, 200)
			draw.OutlinedRect(
				math.floor(headerScreenX),
				math.floor(headerScreenY),
				math.floor(headerScreenX + headerScreenWidth),
				math.floor(headerScreenY + headerScreenHeight)
			)

			-- Draw script name (positioned on board, then transformed)
			if headerScreenHeight > 12 then
				-- Position script name on board, then transform to screen
				local nameBoardX = headerBoardX + 4
				local nameBoardY = headerBoardY + 4
				local nameScreenX, nameScreenY = boardToScreen(nameBoardX, nameBoardY)

				draw.Color(255, 255, 255, 255)
				draw.Text(math.floor(nameScreenX), math.floor(nameScreenY), scriptName)

				-- Function count (positioned on board, then transformed)
				local countText = string.format("(%d functions)", #functions)
				local countBoardX = headerBoardX + headerBoardWidth - 80
				local countBoardY = headerBoardY + 4
				local countScreenX, countScreenY = boardToScreen(countBoardX, countBoardY)

				draw.Text(math.floor(countScreenX), math.floor(countScreenY), countText)
			end
		end
	end

	boardY = boardY + SCRIPT_HEADER_HEIGHT + FUNCTION_SPACING

	-- Draw functions with stacking (cull functions outside visible time window)
	local stackLevels = {} -- Track occupied time ranges at each Y level

	for i, func in ipairs(functions) do
		-- Cull functions completely outside visible time window
		if func.startTime and func.endTime and func.endTime >= dataStartTime and func.startTime <= dataEndTime then
			local boardX = timeToBoardX(func.startTime, dataStartTime)
			local boardWidth = timeToBoardX(func.endTime, dataStartTime) - boardX

			-- Find available Y level
			local level = 0
			local foundLevel = false

			while not foundLevel do
				local conflictFound = false

				if stackLevels[level] then
					for _, occupiedRange in ipairs(stackLevels[level]) do
						if not (func.endTime <= occupiedRange.startTime or func.startTime >= occupiedRange.endTime) then
							conflictFound = true
							break
						end
					end
				end

				if not conflictFound then
					if not stackLevels[level] then
						stackLevels[level] = {}
					end
					table.insert(stackLevels[level], { startTime = func.startTime, endTime = func.endTime })
					foundLevel = true
				else
					level = level + 1
				end
			end

			-- Calculate Y position on board
			local functionBoardY = boardY + (level * (FUNCTION_HEIGHT + FUNCTION_SPACING))

			-- Draw function on board
			drawFunctionOnBoard(func, boardX, functionBoardY, boardWidth, screenW, screenH)
		end
	end

	-- Calculate new Y position after all levels
	local maxLevel = 0
	for level, _ in pairs(stackLevels) do
		maxLevel = math.max(maxLevel, level)
	end
	boardY = boardY + ((maxLevel + 1) * (FUNCTION_HEIGHT + FUNCTION_SPACING))

	return boardY + SCRIPT_SPACING
end

-- Draw fractal time ruler with tick/frame boundaries as primary grid
local function drawTimeRuler(screenW, screenH, topBarHeight, dataStartTime, dataEndTime)
	if not draw then
		return
	end

	-- Ruler background
	draw.Color(30, 30, 30, 255)
	draw.FilledRect(0, topBarHeight, screenW, topBarHeight + RULER_HEIGHT)

	-- Measurement mode
	local mode = Shared.MeasurementMode
	assert(mode == "tick" or mode == "frame", "drawTimeRuler: invalid MeasurementMode")

	local frameTime = globals.TickInterval()

	-- PRIMARY GRID: Tick/Frame boundaries (bold lines)
	-- Only draw if spacing is at least 3px (avoid dense lines when zoomed out)
	local framePixelSpacing = frameTime * TIME_SCALE * boardZoom
	local shouldDrawFrameBoundaries = framePixelSpacing >= 3

	-- Use RecordingStartTime as consistent reference for frame alignment
	-- This ensures grid stays aligned with actual work regardless of viewport
	local recordingStart = Shared.RecordingStartTime or dataStartTime
	local tickStart = math.floor(recordingStart / frameTime) * frameTime

	if shouldDrawFrameBoundaries then
		local tickTime = tickStart
		local tickCount = 0
		local lastDrawnX = -1000 -- Track last drawn position to avoid overlap

		while tickTime <= dataEndTime + frameTime and tickCount < 1000 do
			-- Only draw if time >= dataStartTime (no negative time)
			if tickTime >= dataStartTime then
				local boardX = timeToBoardX(tickTime, dataStartTime)
				local screenX, _ = boardToScreen(boardX, 0)
				local intScreenX = math.floor(screenX + 0.5)

				-- Only draw if on screen and not too close to last line
				if screenX >= -10 and screenX <= screenW + 10 and (intScreenX - lastDrawnX) >= 2 then
					-- Bold tick/frame boundary line
					draw.Color(150, 150, 200, 255)
					draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)

					-- Extend through content area (frame boundary)
					draw.Color(100, 100, 150, 80)
					draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

					-- Label tick/frame number (only if spacing is wide enough)
					if framePixelSpacing >= 25 then
						local label
						if mode == "tick" then
							local tickNum = math.floor((tickTime - recordingStart) / frameTime)
							label = string.format("T%d", tickNum)
						else
							local frameNum = math.floor((tickTime - recordingStart) / frameTime)
							label = string.format("F%d", frameNum)
						end
						draw.Color(200, 200, 255, 255)
						draw.Text(intScreenX + 2, topBarHeight + 2, label)
					end

					lastDrawnX = intScreenX
				end
			end

			tickTime = tickTime + frameTime
			tickCount = tickCount + 1
		end
	end

	-- SECONDARY GRID: Simple linear subdivision
	-- Fixed density subdivision lines across visible time range
	local targetPixelSpacing = 50
	local timeInterval = targetPixelSpacing / (TIME_SCALE * boardZoom)

	-- Round interval to nice number (1, 2, 5 pattern)
	local magnitudes = {
		0.000001,
		0.000002,
		0.000005,
		0.00001,
		0.00002,
		0.00005,
		0.0001,
		0.0002,
		0.0005,
		0.001,
		0.002,
		0.005,
		0.01,
		0.02,
		0.05,
		0.1,
		0.2,
		0.5,
		1.0,
		2.0,
		5.0,
	}
	local interval = magnitudes[1]
	for _, mag in ipairs(magnitudes) do
		if mag >= timeInterval then
			interval = mag
			break
		end
	end

	-- Draw subdivision lines across visible time range
	local startMark = math.floor(dataStartTime / interval) * interval
	local time = startMark
	local lastLabelEndX = -1000
	local markCount = 0

	while time <= dataEndTime and markCount < 500 do
		if time >= dataStartTime then
			local boardX = timeToBoardX(time, dataStartTime)
			local screenX, _ = boardToScreen(boardX, 0)

			if screenX >= 0 and screenX <= screenW then
				local intScreenX = math.floor(screenX + 0.5)

				-- Subdivision line
				draw.Color(100, 100, 100, 80)
				draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)
				draw.Color(80, 80, 80, 20)
				draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

				-- Label with absolute time from RecordingStartTime
				local absoluteTime = time - recordingStart
				local label
				if interval >= 0.001 then
					label = string.format("%.1fms", absoluteTime * 1000)
				else
					label = string.format("%.0fµs", absoluteTime * 1000000)
				end

				local textWidth = #label * 7 + 10
				local textX = intScreenX + 2
				if textX >= lastLabelEndX + 10 and screenX >= 10 and screenX <= screenW - textWidth then
					draw.Color(150, 150, 150, 200)
					draw.Text(textX, topBarHeight + 15, label)
					lastLabelEndX = textX + textWidth
				end
			end
		end

		time = time + interval
		markCount = markCount + 1
	end
end

-- Handle input for board navigation
local function handleBoardInput(screenW, screenH, topBarHeight)
	if not input or not input.GetMousePos then
		return
	end

	local pos = input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Only handle input in body area
	if my < topBarHeight then
		return
	end

	local bodyMy = my - topBarHeight

	-- Handle dragging - move the board
	local currentlyDragging = input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)

	if currentlyDragging and not isDragging then
		-- Start drag
		isDragging = true
		lastMouseX = mx
		lastMouseY = bodyMy
	elseif currentlyDragging and isDragging then
		-- Continue drag - move board in opposite direction of mouse
		local deltaX = mx - lastMouseX
		local deltaY = bodyMy - lastMouseY

		-- Calculate new offset
		local newOffsetX = boardOffsetX - (deltaX / boardZoom)
		local newOffsetY = boardOffsetY - (deltaY / boardZoom)

		-- No Y scrolling - lock Y offset to 0
		newOffsetY = 0

		-- No horizontal clamping - allow moving left/right freely

		-- Apply clamped offsets
		boardOffsetX = newOffsetX
		boardOffsetY = newOffsetY

		lastMouseX = mx
		lastMouseY = bodyMy
	elseif not currentlyDragging and isDragging then
		-- End drag
		isDragging = false
	end

	-- Handle zoom with Q/E keys - zoom towards mouse position
	if input.IsButtonDown then
		local qPressed = input.IsButtonDown(KEY_Q)
		local ePressed = input.IsButtonDown(KEY_E)

		if qPressed or ePressed then
			local oldZoom = boardZoom

			if qPressed then
				boardZoom = boardZoom * 1.1 -- Zoom in
			elseif ePressed then
				boardZoom = boardZoom / 1.1 -- Zoom out
			end

			-- Clamp zoom based on RealTime precision
			-- Lua doubles have ~15-17 significant digits
			-- At 4722s, smallest delta is ~0.0001s (100μs precision)
			-- Max useful zoom: 3px = 0.0001s * TIME_SCALE * zoom
			-- zoom = 3 / (0.0001 * 50000) = 0.6 is too low
			-- Use 100μs precision -> max zoom ~1000x for 3px spacing at 100μs
			local maxZoom = 1000.0
			boardZoom = math.max(0.01, math.min(maxZoom, boardZoom))

			-- Zoom towards mouse position - keep the point under mouse cursor fixed
			-- Convert mouse screen position to board position BEFORE zoom change
			local mouseBoardX = (mx / oldZoom) + boardOffsetX
			local mouseBoardY = (bodyMy / oldZoom) + boardOffsetY

			-- No Y scrolling - lock Y offset to 0
			local newOffsetY = 0

			-- Adjust offset so the same board point stays under the mouse cursor
			local newOffsetX = mouseBoardX - (mx / boardZoom)

			-- No horizontal clamping - allow moving left/right freely

			-- Apply clamped offsets
			boardOffsetX = newOffsetX
			boardOffsetY = newOffsetY
		end
	end
end

-- Public API
function UIBody.Initialize()
	boardOffsetX = 0
	boardOffsetY = 0
	boardZoom = 1.0
	isDragging = false
	print("🎨 UIBody initialized - TIME_SCALE = 50000 px/s (1ms = 50px)")
end

function UIBody.SetVisible(visible)
	Shared.UIBodyVisible = visible
end

function UIBody.IsVisible()
	return Shared.UIBodyVisible or false
end

function UIBody.ToggleVisible()
	local newVisibility = not (Shared.UIBodyVisible or false)
	UIBody.SetVisible(newVisibility)
	return newVisibility
end

function UIBody.Draw(profilerData, topBarHeight)
	if not draw or not profilerData then
		return
	end

	-- Reset hovered function at start of frame
	hoveredFunc = nil

	-- Store topBarHeight for use in boardToScreen
	currentTopBarHeight = topBarHeight or 60

	local screenW, screenH = draw.GetScreenSize()

	-- Draw background
	draw.Color(20, 20, 20, 240)
	draw.FilledRect(0, topBarHeight, screenW, screenH)

	-- Keep only last 10 seconds of history to prevent infinite growth
	local currentTime = os.clock()
	local MAX_HISTORY_TIME = 10.0
	local recordingStart = Shared.RecordingStartTime or currentTime
	local cutoffTime = currentTime - MAX_HISTORY_TIME

	-- Clean old data beyond time window
	if profilerData.scriptTimelines then
		for scriptName, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions then
				local cleaned = {}
				for _, func in ipairs(scriptData.functions) do
					if func.endTime and func.endTime >= cutoffTime then
						table.insert(cleaned, func)
					end
				end
				scriptData.functions = cleaned
			end
		end
	end

	-- Calculate visible time window based on current viewport
	local visibleTimeWidth = (screenW / boardZoom) / TIME_SCALE
	local dataStartTime = recordingStart + (boardOffsetX / TIME_SCALE)
	local dataEndTime = dataStartTime + visibleTimeWidth

	-- Draw time ruler (includes frame/tick boundaries and ms subdivisions)
	drawTimeRuler(screenW, screenH, topBarHeight, dataStartTime, dataEndTime)

	-- Start drawing on virtual board (FIXED position below ruler, not zoom-scaled)
	-- Content always starts at screenY = topBarHeight + RULER_HEIGHT
	-- In board coordinates, this means boardY = boardOffsetY + (RULER_HEIGHT / boardZoom)
	local boardY = 0 -- Board Y position for first script

	-- Draw each script's functions on the board
	if profilerData.scriptTimelines then
		for scriptName, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions and #scriptData.functions > 0 then
				boardY = drawScriptOnBoard(
					scriptName,
					scriptData.functions,
					boardY,
					dataStartTime,
					dataEndTime,
					screenW,
					screenH
				)
			end
		end
	end

	-- Draw hover tooltip if function is hovered
	if hoveredFunc and input and input.GetMousePos then
		local pos = input.GetMousePos()
		local mx, my = pos[1] or 0, pos[2] or 0
		local tooltipX = mx + 15
		local tooltipY = my + 15
		local tooltipW = 220
		local tooltipH = 70

		if tooltipX + tooltipW > screenW then
			tooltipX = mx - tooltipW - 5
		end
		if tooltipY + tooltipH > screenH then
			tooltipY = my - tooltipH - 5
		end

		draw.Color(20, 20, 20, 240)
		draw.FilledRect(tooltipX, tooltipY, tooltipX + tooltipW, tooltipY + tooltipH)
		draw.Color(150, 200, 255, 255)
		draw.OutlinedRect(tooltipX, tooltipY, tooltipX + tooltipW, tooltipY + tooltipH)

		local textX = tooltipX + 5
		local textY = tooltipY + 5
		draw.Color(255, 255, 255, 255)
		draw.Text(textX, textY, hoveredFunc.name or "unknown")

		local durationMs = (hoveredFunc.endTime - hoveredFunc.startTime) * 1000
		draw.Color(255, 255, 150, 255)
		draw.Text(textX, textY + 18, string.format("Duration: %.3fms", durationMs))

		local memKb = hoveredFunc.memDelta or 0
		local memMb = memKb / 1024
		local memText = memMb >= 1 and string.format("Memory: %.2f MB", memMb)
			or string.format("Memory: %.1f KB", memKb)
		draw.Color(150, 255, 150, 255)
		draw.Text(textX, textY + 36, memText)

		if hoveredFunc.scriptName then
			draw.Color(200, 200, 200, 255)
			draw.Text(textX, textY + 54, "Script: " .. hoveredFunc.scriptName)
		end
	end

	-- Draw info overlay
	draw.Color(255, 255, 255, 255)
	draw.Text(10, screenH - 95, string.format("Board Zoom: %.2fx", boardZoom))
	draw.Text(10, screenH - 80, string.format("Board Offset: X=%.0f Y=%.0f", boardOffsetX, boardOffsetY))
	draw.Text(10, screenH - 65, string.format("Time Range: %.3fs - %.3fs", dataStartTime, dataEndTime))
	draw.Text(10, screenH - 50, string.format("Time Scale: %.1f px/s", TIME_SCALE))
	draw.Text(10, screenH - 35, "Drag=Move Board, Q=Zoom In, E=Zoom Out")
	draw.Text(10, screenH - 20, string.format("Dragging: %s", tostring(isDragging)))

	-- Handle input
	handleBoardInput(screenW, screenH, topBarHeight)
end

-- Camera controls
function UIBody.ResetCamera()
	boardOffsetX = 0
	boardOffsetY = 0
	boardZoom = 1.0
end

function UIBody.SetZoom(newZoom)
	local maxZoom = 1000.0 -- Based on RealTime precision (~100μs)
	boardZoom = math.max(0.01, math.min(maxZoom, newZoom))
end

function UIBody.GetZoom()
	return boardZoom
end

function UIBody.CenterOnTimestamp(timestamp)
	-- Center the board on the given timestamp
	if timestamp then
		-- Calculate board X position for this timestamp
		local boardX = timestamp * TIME_SCALE
		-- Center it on screen (assuming screen width of ~1920)
		boardOffsetX = boardX - (960 / boardZoom)
	end
end

return UIBody
