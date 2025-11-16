--[[
    Simple UI Body Module - Virtual Profiler Board
    All elements positioned on fixed coordinate system, then board is transformed
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]
local UILayout = require("Profiler.ui_layout")
local UIRender = require("Profiler.ui_render")

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

-- Global state (retained mode)
local boardOffsetX = 0 -- Camera position on virtual board
local boardOffsetY = 0 -- Camera position on virtual board
local boardZoom = 1.0 -- Zoom level of the board
local isDragging = false
local lastMouseX, lastMouseY = 0, 0
local currentTopBarHeight = 60 -- Current top bar height (updated each frame)

-- External APIs
local draw = draw
local input = input
local MOUSE_LEFT = MOUSE_LEFT or 107
local KEY_Q = KEY_Q or 18
local KEY_E = KEY_E or 20

-- Safely require external globals library (provides RealTime, FrameTime)
local globals = nil -- External globals library (RealTime, FrameTime)
local ok, globalsModule = pcall(require, "globals")
if ok then
	globals = globalsModule
end

-- Helper functions
-- Use globals.RealTime() directly

-- Convert time to board X coordinate
-- startTime is the reference for the current visible window (usually dataStartTime)
local function timeToBoardX(time, startTime)
	return (time - startTime) * TIME_SCALE
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

	-- Only draw if visible on screen (use actual screen bounds)
	if
		screenX + screenWidth > 0
		and screenX < screenW
		and screenY + screenHeight > currentTopBarHeight
		and screenY < screenH
	then
		-- Draw function bar
		draw.Color(100, 150, 200, 180)
		draw.FilledRect(
			math.floor(screenX),
			math.floor(screenY),
			math.floor(screenX + screenWidth),
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

				if gridScreenX >= screenX and gridScreenX <= screenX + screenWidth then
					draw.Color(255, 255, 255, 30)
					draw.Line(
						math.floor(gridScreenX),
						math.floor(screenY),
						math.floor(gridScreenX),
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
			math.floor(screenX),
			math.floor(screenY),
			math.floor(screenX + screenWidth),
			math.floor(screenY + screenHeight)
		)

		-- Draw function name if it fits (positioned on board, then transformed)
		local name = func.name or "unknown"
		if screenWidth > 50 and screenHeight > 12 then
			-- Position text on board, then transform to screen
			local textBoardX = boardX + 4
			local textBoardY = boardY + 2
			local textScreenX, textScreenY = boardToScreen(textBoardX, textBoardY)

			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(textScreenX), math.floor(textScreenY), name)
		end

		-- Draw duration if there's space (positioned on board, then transformed)
		if screenWidth > 120 and screenHeight > 24 then
			local durationMs = duration * 1000 -- ms
			local durationText = string.format("%.3fms", durationMs)

			-- Position duration text on board, then transform to screen
			local durationBoardX = boardX + 4
			local durationBoardY = boardY + FUNCTION_HEIGHT - 12
			local durationScreenX, durationScreenY = boardToScreen(durationBoardX, durationBoardY)

			draw.Color(255, 255, 100, 255)
			draw.Text(math.floor(durationScreenX), math.floor(durationScreenY), durationText)
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

	-- Draw functions with stacking
	local stackLevels = {} -- Track occupied time ranges at each Y level

	for i, func in ipairs(functions) do
		if func.startTime and func.endTime then
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
	local mode = Shared.MeasurementMode or "frame"

	-- Get frame/tick time
	local frameTime = (globals and globals.FrameTime and globals.FrameTime()) or 0.015
	if frameTime <= 0 then
		frameTime = 0.015
	end

	-- PRIMARY GRID: Tick/Frame boundaries (bold lines with T/F labels)
	local framePixelSpacing = frameTime * TIME_SCALE * boardZoom
	local shouldDrawFrameBoundaries = framePixelSpacing >= 3

	-- dataStartTime is already aligned to first frame boundary by caller
	local tickStart = dataStartTime

	if shouldDrawFrameBoundaries then
		local tickTime = tickStart
		local tickIndex = 0
		local lastDrawnX = -1000

		while tickTime <= dataEndTime + frameTime and tickIndex < 1000 do
			local boardX = timeToBoardX(tickTime, dataStartTime)
			local screenX, _ = boardToScreen(boardX, 0)
			local intScreenX = math.floor(screenX + 0.5)

			-- Only draw if on screen and not too close to last line
			if screenX >= -10 and screenX <= screenW + 10 and (intScreenX - lastDrawnX) >= 2 then
				-- Bold tick/frame boundary line
				draw.Color(150, 150, 200, 255)
				draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)

				-- Extend through content area
				draw.Color(100, 100, 150, 80)
				draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

				-- Label with T# or F# (always show, based on tick index from start)
				if framePixelSpacing >= 25 then
					local label
					if mode == "tick" then
						label = string.format("T%d", tickIndex)
					else
						label = string.format("F%d", tickIndex)
					end
					draw.Color(200, 200, 255, 255)
					draw.Text(intScreenX + 2, topBarHeight + 2, label)
				end

				lastDrawnX = intScreenX
			end

			tickTime = tickTime + frameTime
			tickIndex = tickIndex + 1
		end
	end

	-- SECONDARY GRID: Time subdivisions with CLEAN distinct labels
	-- Show absolute time from recording start (never duplicates)

	local minPixelSpacing = 40 -- Wider spacing for cleaner labels
	local minInterval = 0.0001 -- 100µs minimum

	-- Pick ONE best interval based on zoom
	local targetPixelSpacing = 60
	local bestInterval = minInterval
	local base = minInterval

	while base < 10.0 do
		for _, scale in ipairs({ 1, 2, 5 }) do
			local mag = base * scale
			local pixelSpacing = mag * TIME_SCALE * boardZoom
			if pixelSpacing >= minPixelSpacing and pixelSpacing <= 120 then
				if
					math.abs(pixelSpacing - targetPixelSpacing)
					< math.abs(bestInterval * TIME_SCALE * boardZoom - targetPixelSpacing)
				then
					bestInterval = mag
				end
			end
		end
		base = base * 10
	end

	local interval = bestInterval
	local pixelsPerInterval = interval * TIME_SCALE * boardZoom

	-- Only draw if spacing is reasonable
	if pixelsPerInterval >= minPixelSpacing then
		-- Start from first interval mark at or after dataStartTime
		local firstMark = math.ceil(dataStartTime / interval) * interval
		local time = firstMark
		local lastLabelEndX = -1000

		while time <= dataEndTime and time - dataStartTime < 100.0 do
			local boardX = timeToBoardX(time, dataStartTime)
			local screenX, _ = boardToScreen(boardX, 0)

			if screenX >= -10 and screenX <= screenW + 10 then
				local intScreenX = math.floor(screenX + 0.5)

				-- Subdivision line
				draw.Color(100, 100, 100, 120)
				draw.Line(intScreenX, topBarHeight, intScreenX, topBarHeight + RULER_HEIGHT)
				draw.Color(80, 80, 80, 30)
				draw.Line(intScreenX, topBarHeight + RULER_HEIGHT, intScreenX, screenH)

				-- ABSOLUTE time from recording start (distinct values)
				local absoluteTime = time - dataStartTime
				local label

				-- Clean distinct intervals: 1,2,3 or 10,20,30 or 100,200,300
				local timeInMs = absoluteTime * 1000
				local timeInUs = absoluteTime * 1000000

				if interval >= 0.01 then
					-- Milliseconds: show whole numbers when >= 10ms
					if timeInMs >= 10 then
						label = string.format("%dms", math.floor(timeInMs + 0.5))
					else
						label = string.format("%.1fms", timeInMs)
					end
				else
					-- Microseconds: show whole numbers when >= 10µs
					if timeInUs >= 10 then
						label = string.format("%dµs", math.floor(timeInUs + 0.5))
					else
						label = string.format("%.1fµs", timeInUs)
					end
				end

				-- Draw label if not overlapping
				local estimatedWidth = #label * 7 + 10
				if (intScreenX - lastLabelEndX) > estimatedWidth then
					draw.Color(180, 180, 200, 220)
					draw.Text(intScreenX + 2, topBarHeight + 15, label)
					lastLabelEndX = intScreenX + estimatedWidth
				end
			end

			time = time + interval
		end
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

		-- Clamp Y offset - prevent scrolling zones above screen top
		-- Minimum Y offset is 0 (zones start at topBarHeight)
		newOffsetY = math.max(0, newOffsetY)

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

			-- Adjust offsets so the same board point stays under the mouse cursor
			local newOffsetX = mouseBoardX - (mx / boardZoom)
			local newOffsetY = mouseBoardY - (bodyMy / boardZoom)

			-- Clamp Y offset - prevent scrolling zones above screen top
			newOffsetY = math.max(0, newOffsetY)

			-- Apply offsets
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

	local screenW, screenH = draw.GetScreenSize()

	-- Draw background
	draw.Color(20, 20, 20, 240)
	draw.FilledRect(0, topBarHeight, screenW, screenH)

	-- Calculate time bounds
	local dataStartTime = math.huge
	local dataEndTime = -math.huge

	if profilerData.scriptTimelines then
		for _, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions then
				for _, func in ipairs(scriptData.functions) do
					if func.startTime and func.endTime then
						dataStartTime = math.min(dataStartTime, func.startTime)
						dataEndTime = math.max(dataEndTime, func.endTime)
					end
				end
			end
		end
	end

	-- Fallback
	if dataStartTime == math.huge then
		if globals and globals.RealTime then
			dataStartTime = globals.RealTime() - 5
			dataEndTime = globals.RealTime()
		else
			dataStartTime = 0
			dataEndTime = 5
		end
	end

	-- Get frame time
	local frameTime = (globals and globals.FrameTime and globals.FrameTime()) or 0.015
	if frameTime <= 0 then
		frameTime = 0.015
	end

	-- Align to recording start
	local recordingStart = Shared.RecordingStartTime or dataStartTime
	if dataStartTime < recordingStart then
		dataStartTime = recordingStart
	end

	local alignedOrigin = math.ceil(dataStartTime / frameTime) * frameTime

	-- Create dual-zone layout
	local layout = UILayout.CreateLayout(profilerData, topBarHeight, screenH)

	-- Draw tick zone
	if layout.tickZone then
		UIRender.DrawZone(
			layout.tickZone,
			"tick",
			0,
			layout.tickZone.startY,
			screenW,
			screenH,
			alignedOrigin,
			dataEndTime,
			frameTime,
			boardZoom,
			boardOffsetX,
			boardOffsetY
		)
	end

	-- Draw frame zone
	if layout.frameZone then
		UIRender.DrawZone(
			layout.frameZone,
			"frame",
			0,
			layout.frameZone.startY,
			screenW,
			screenH,
			alignedOrigin,
			dataEndTime,
			frameTime,
			boardZoom,
			boardOffsetX,
			boardOffsetY
		)
	end

	-- Debug info
	draw.Color(255, 255, 255, 255)
	draw.Text(
		10,
		screenH - 65,
		string.format("Zoom: %.2fx | Offset: X=%.0f Y=%.0f", boardZoom, boardOffsetX, boardOffsetY)
	)
	draw.Text(10, screenH - 50, "Drag=Pan (X+Y) | Q=Zoom In | E=Zoom Out")
	draw.Text(10, screenH - 35, string.format("Time: %.3fs - %.3fs", alignedOrigin, dataEndTime))

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
