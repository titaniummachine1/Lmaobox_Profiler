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
local MAX_TICKS = 66 -- Maximum ticks of history to display (T1-T66)
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
local funcCache = {}
local globalTextSizeCache = {}
-- Fixed-size text cache (no memory leaks, no table growth)
-- Structure: cache[name] = { [pixelWidth] = truncatedString }
-- We store at most MAX_TEXT_CACHE_ENTRIES function names
local textCache = {}
local textCacheOrder = {} -- For LRU tracking (indices 1..MAX)
local textCacheIndex = {} -- name -> position in textCacheOrder
local textCacheCount = 0
local MAX_TEXT_CACHE_ENTRIES = 1000
local nextCacheSlot = 1 -- Round-robin eviction pointer

-- Per-frame update limit
local maxTextUpdatesPerFrame = 50
local updatesThisFrame = 0

-- External APIs
local draw_raw = draw
local input = input
local MOUSE_LEFT = MOUSE_LEFT or 107
local KEY_Q = KEY_Q or 18
local KEY_E = KEY_E or 20
local MOUSE_WHEEL_UP = MOUSE_WHEEL_UP or 112
local MOUSE_WHEEL_DOWN = MOUSE_WHEEL_DOWN or 113

-- Safe coordinate validation
local function isValidNumber(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function clampCoord(n, min, max)
	if not isValidNumber(n) then
		return min or 0
	end
	if min and n < min then
		return min
	end
	if max and n > max then
		return max
	end
	return math.floor(n + 0.5)
end

-- Safe draw wrappers
local draw = {}
setmetatable(draw, {
	__index = function(t, k)
		return draw_raw[k]
	end,
})

function draw.FilledRect(x1, y1, x2, y2)
	x1 = clampCoord(x1, -10000, 10000)
	y1 = clampCoord(y1, -10000, 10000)
	x2 = clampCoord(x2, -10000, 10000)
	y2 = clampCoord(y2, -10000, 10000)
	return draw_raw.FilledRect(x1, y1, x2, y2)
end

function draw.OutlinedRect(x1, y1, x2, y2)
	x1 = clampCoord(x1, -10000, 10000)
	y1 = clampCoord(y1, -10000, 10000)
	x2 = clampCoord(x2, -10000, 10000)
	y2 = clampCoord(y2, -10000, 10000)
	return draw_raw.OutlinedRect(x1, y1, x2, y2)
end

function draw.Line(x1, y1, x2, y2)
	x1 = clampCoord(x1, -10000, 10000)
	y1 = clampCoord(y1, -10000, 10000)
	x2 = clampCoord(x2, -10000, 10000)
	y2 = clampCoord(y2, -10000, 10000)
	return draw_raw.Line(x1, y1, x2, y2)
end

function draw.Text(x, y, text)
	x = clampCoord(x, -10000, 10000)
	y = clampCoord(y, -10000, 10000)
	return draw_raw.Text(x, y, text)
end

function draw.Color(r, g, b, a)
	return draw_raw.Color(r, g, b, a)
end

function draw.GetScreenSize()
	return draw_raw.GetScreenSize()
end

function draw.GetTextSize(text)
	return draw_raw.GetTextSize(text)
end

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

local function getTextSize(text)
	assert(draw and draw.GetTextSize, "getTextSize: draw.GetTextSize missing")
	if globalTextSizeCache[text] then
		return globalTextSizeCache[text].w, globalTextSizeCache[text].h
	end
	local w, h = draw.GetTextSize(text)
	globalTextSizeCache[text] = { w = w, h = h }
	return w, h
end

local function getFunctionHeight(func)
	assert(func, "getFunctionHeight: func missing")
	if func._cachedHeight then
		return func._cachedHeight
	end
	local memDeltaKb = func.memDelta
	assert(type(memDeltaKb) == "number", "getFunctionHeight: memDelta invalid")
	if memDeltaKb < 0 then
		memDeltaKb = 0
	end
	local height
	if memDeltaKb < 10 then
		height = FUNCTION_HEIGHT
	else
		local logScale = math.log(memDeltaKb / 10) / math.log(10)
		local additionalHeight = logScale * 30
		height = FUNCTION_HEIGHT + additionalHeight
	end
	func._cachedHeight = height
	return height
end

-- Generate color: random distribution shifts from cold to warm spectrum with memory
local function getFunctionColor(func)
	assert(func, "getFunctionColor: func missing")

	if func._cachedColor then
		return func._cachedColor.r, func._cachedColor.g, func._cachedColor.b
	end

	local memKb = func.memDelta or 0
	local memMb = memKb / 1024

	local name = func.name or "unknown"
	local hash = 0
	for i = 1, #name do
		hash = (hash * 31 + string.byte(name, i)) % 2147483647
	end

	local hueMin, hueMax
	if memMb < 0.5 then
		hueMin = 180
		hueMax = 240
	elseif memMb < 2 then
		local t = (memMb - 0.5) / 1.5
		hueMin = 180 - t * 60
		hueMax = 240 - t * 80
	elseif memMb < 5 then
		local t = (memMb - 2) / 3
		hueMin = 120 - t * 60
		hueMax = 160 - t * 100
	elseif memMb < 10 then
		local t = (memMb - 5) / 5
		hueMin = 60 - t * 40
		hueMax = 60 - t * 30
	else
		hueMin = 0
		hueMax = 15
	end

	local hueRange = hueMax - hueMin
	local hue = (hueMin + (hash % math.max(1, math.floor(hueRange)))) / 360
	local saturation = 0.55 + ((hash % 25) / 100)
	local value = 0.7 + ((hash % 20) / 100)

	local function hsvToRgb(h, s, v)
		local c = v * s
		local x = c * (1 - math.abs((h * 6) % 2 - 1))
		local m = v - c

		local rr, gg, bb
		if h < 1 / 6 then
			rr, gg, bb = c, x, 0
		elseif h < 2 / 6 then
			rr, gg, bb = x, c, 0
		elseif h < 3 / 6 then
			rr, gg, bb = 0, c, x
		elseif h < 4 / 6 then
			rr, gg, bb = 0, x, c
		elseif h < 5 / 6 then
			rr, gg, bb = x, 0, c
		else
			rr, gg, bb = c, 0, x
		end

		return (rr + m) * 255, (gg + m) * 255, (bb + m) * 255
	end

	local r, g, b = hsvToRgb(hue, saturation, value)

	r = math.floor(r + 0.5)
	g = math.floor(g + 0.5)
	b = math.floor(b + 0.5)

	func._cachedColor = { r = r, g = g, b = b }
	return r, g, b
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

-- Get or create cached truncated text for a name at given pixel width
-- Uses fixed-size cache with round-robin eviction
local function getCachedTruncatedText(name, availablePixels)
	-- Quick reject: if can't fit even 1 char, return empty
	if availablePixels < 8 then
		return "", 0
	end

	-- Check if we have this name cached
	local nameCache = textCache[name]
	if not nameCache then
		-- Need to create new entry - use round-robin if at capacity
		if textCacheCount >= MAX_TEXT_CACHE_ENTRIES then
			-- Evict the oldest entry
			local evictName = textCacheOrder[nextCacheSlot]
			if evictName then
				textCache[evictName] = nil
				textCacheIndex[evictName] = nil
				textCacheCount = textCacheCount - 1
			end
		end

		-- Create new entry at current slot
		nameCache = {}
		textCache[name] = nameCache
		textCacheOrder[nextCacheSlot] = name
		textCacheIndex[name] = nextCacheSlot
		textCacheCount = textCacheCount + 1
		nextCacheSlot = nextCacheSlot + 1
		if nextCacheSlot > MAX_TEXT_CACHE_ENTRIES then
			nextCacheSlot = 1
		end
	end

	-- Check if we have this exact pixel width cached
	local cached = nameCache[availablePixels]
	if cached then
		return cached.text, cached.width
	end

	-- Need to calculate truncation
	local nameW, nameH = getTextSize(name)
	local padding = 4

	if availablePixels >= nameW + padding * 2 then
		-- Full name fits
		nameCache[availablePixels] = { text = name, width = nameW }
		return name, nameW
	end

	-- Need to truncate
	local charWidth = nameW / #name
	local maxChars = math.floor((availablePixels - padding * 2 - charWidth * 2) / charWidth)

	if maxChars <= 0 then
		-- Can't fit even truncated
		nameCache[availablePixels] = { text = "", width = 0 }
		return "", 0
	end

	local truncated = name:sub(1, maxChars) .. ".."
	local truncatedW = getTextSize(truncated)
	nameCache[availablePixels] = { text = truncated, width = truncatedW }

	return truncated, truncatedW
end

-- Draw a function bar on the virtual board with memory-based height scaling
local function drawFunctionOnBoard(func, boardX, boardY, boardWidth, screenW, screenH)
	if not func.startTime or not func.endTime or not draw then
		return
	end

	-- Convert board coordinates to screen coordinates
	local screenX, screenY = boardToScreen(boardX, boardY)
	local screenWidth = boardWidth * boardZoom
	local screenHeight = getFunctionHeight(func)

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

		-- Draw function bar with fancy colors (highlight if hovered)
		local r, g, b = getFunctionColor(func)
		if isHovered then
			draw.Color(math.min(255, r + 50), math.min(255, g + 50), math.min(255, b + 50), 220)
		else
			draw.Color(r, g, b, 180)
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

		-- Text drawing with improved priority: name first, time on right if fits, memory below if fits
		local name = func.name or "unknown"
		if not func._dynamicText then
			local durationUs = duration * 1000000
			local durationText
			if durationUs >= 1000 then
				durationText = string.format("%.2f ms", durationUs / 1000)
			else
				durationText = string.format("%.0f µs", durationUs)
			end

			local memKb = func.memDelta or 0
			local memMb = memKb / 1024
			local memText = memMb >= 1 and string.format("%.2f MB", memMb) or string.format("%.1f KB", memKb)

			local durationW, durationH = getTextSize(durationText)
			local memW, memH = getTextSize(memText)

			func._dynamicText = {
				duration = durationText,
				memory = memText,
				durationW = durationW,
				durationH = durationH,
				memW = memW,
				memH = memH,
			}
		end
		local durationText = func._dynamicText.duration
		local memText = func._dynamicText.memory
		local durationW = func._dynamicText.durationW
		local durationH = func._dynamicText.durationH
		local memW = func._dynamicText.memW
		local memH = func._dynamicText.memH

		if draw.GetTextSize then
			local barWidthScreen = boardWidth * boardZoom
			local barHeight = getFunctionHeight(func)
			local padding = 4
			local lineSpacing = 2

			-- Use cached text lookup (no per-function cache, shared global cache)
			local displayName, actualNameW = getCachedTruncatedText(name, barWidthScreen - padding * 2)
			local _, nameH = getTextSize(name)

			if displayName ~= "" and barWidthScreen >= padding * 2 then
				local nameScreenX = screenX + padding
				local nameScreenY = screenY + 2

				if nameScreenX + actualNameW > 0 and nameScreenX < screenW then
					draw.Color(255, 255, 255, 255)
					draw.Text(math.floor(nameScreenX), math.floor(nameScreenY), displayName)
				end

				-- Only draw time if it fits without overlapping name
				local showTime = false
				local timeScreenX = screenX + barWidthScreen - durationW - padding
				if timeScreenX > nameScreenX + actualNameW + padding then
					showTime = true
				end

				if showTime and timeScreenX + durationW > 0 and timeScreenX < screenW then
					draw.Color(255, 255, 100, 255)
					draw.Text(math.floor(timeScreenX), math.floor(nameScreenY), durationText)
				end

				local showMemory = false
				if barHeight > nameH + memH + lineSpacing + 4 then
					if barWidthScreen > memW + padding * 2 then
						showMemory = true
					end
				end

				if showMemory then
					local memScreenX = screenX + padding
					local memScreenY = screenY + nameH + lineSpacing + 2

					if memScreenX + memW > 0 and memScreenX < screenW then
						draw.Color(150, 255, 150, 255)
						draw.Text(math.floor(memScreenX), math.floor(memScreenY), memText)
					end
				end
			end
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

	local scriptCacheKey = scriptName
	if not funcCache[scriptCacheKey] then
		funcCache[scriptCacheKey] = {}
	end
	local scriptLayoutCache = funcCache[scriptCacheKey]

	local needsLayoutCalc = false
	for _, func in ipairs(functions) do
		if func._cachedLayoutY == nil then
			needsLayoutCalc = true
			break
		end
	end

	if needsLayoutCalc then
		local occupiedRegions = {}

		local function calculateLayout(func, minY)
			if not func.startTime or not func.endTime then
				return
			end

			local funcHeight = getFunctionHeight(func)
			local currentY = minY
			local foundPosition = false

			while not foundPosition do
				local collisionFound = false

				for _, region in ipairs(occupiedRegions) do
					local timeOverlap = not (func.endTime <= region.startTime or func.startTime >= region.endTime)
					local yOverlap = not (
						currentY + funcHeight + FUNCTION_SPACING <= region.y
						or currentY >= region.y + region.height + FUNCTION_SPACING
					)

					if timeOverlap and yOverlap then
						collisionFound = true
						currentY = region.y + region.height + FUNCTION_SPACING
						break
					end
				end

				if not collisionFound then
					table.insert(occupiedRegions, {
						startTime = func.startTime,
						endTime = func.endTime,
						y = currentY,
						height = funcHeight,
					})
					foundPosition = true
				end
			end

			func._cachedLayoutY = currentY

			if func.children and #func.children > 0 then
				for _, child in ipairs(func.children) do
					calculateLayout(child, currentY + funcHeight + FUNCTION_SPACING)
				end
			end
		end

		for _, func in ipairs(functions) do
			calculateLayout(func, 0)
		end

		local maxY = 0
		for _, region in ipairs(occupiedRegions) do
			maxY = math.max(maxY, region.y + region.height)
		end
		scriptLayoutCache.maxY = maxY
	end

	local function drawFunc(func)
		if not func.startTime or not func.endTime or not func._cachedLayoutY then
			return
		end

		if func.endTime < dataStartTime or func.startTime > dataEndTime then
			return
		end

		local boardX = timeToBoardX(func.startTime, dataStartTime)
		local boardWidth = timeToBoardX(func.endTime, dataStartTime) - boardX
		local currentY = func._cachedLayoutY
		local functionBoardY = boardY + currentY

		drawFunctionOnBoard(func, boardX, functionBoardY, boardWidth, screenW, screenH)

		if func.children and #func.children > 0 then
			for _, child in ipairs(func.children) do
				drawFunc(child)
			end
		end
	end

	for _, func in ipairs(functions) do
		drawFunc(func)
	end

	local maxY = scriptLayoutCache.maxY or 0
	boardY = boardY + maxY + FUNCTION_SPACING

	return boardY + SCRIPT_SPACING
end

-- Draw time ruler with fixed pixel spacing (works at infinite zoom)
-- Uses actual tick boundaries from stored tick counts in profiler data
local function drawTimeRuler(
	screenW,
	screenH,
	rulerY,
	dataStartTime,
	dataEndTime,
	tickBoundaries,
	minTick,
	maxTick,
	contextLabel
)
	if not draw then
		return
	end

	-- Ruler background
	draw.Color(30, 30, 30, 255)
	draw.FilledRect(0, rulerY, screenW, rulerY + RULER_HEIGHT)

	-- Context label
	if contextLabel then
		draw.Color(255, 255, 100, 255)
		draw.Text(5, rulerY + 2, contextLabel)
	end

	-- Fixed pixel spacing between subdivision lines (constant on screen)
	local PIXEL_SPACING = 80

	-- Get visible time range from screen coordinates
	local visibleLeftBoardX = boardOffsetX
	local visibleRightBoardX = boardOffsetX + (screenW / boardZoom)

	-- Convert board X to time (board X is in pixels at TIME_SCALE)
	local visibleLeftTime = dataStartTime + (visibleLeftBoardX / TIME_SCALE)
	local visibleRightTime = dataStartTime + (visibleRightBoardX / TIME_SCALE)

	-- Calculate time per pixel at current zoom
	local timePerPixel = 1 / (TIME_SCALE * boardZoom)

	-- Time between each subdivision line (fixed pixel spacing)
	local timePerLine = PIXEL_SPACING * timePerPixel

	-- Fallback if no tick data
	if minTick == math.huge or not tickBoundaries then
		minTick = 0
		maxTick = MAX_TICKS
		tickBoundaries = {}
	end

	local lastLabelEndX = -1000

	-- Calculate total tick count and sliding window
	local totalTicks = maxTick - minTick + 1
	local displayStartTick = minTick

	-- If more than 66 ticks, only show the last 66
	if totalTicks > MAX_TICKS then
		displayStartTick = maxTick - MAX_TICKS + 1
	end

	-- Fallback duration if boundary missing
	local fallbackDuration = contextLabel == "FRAME" and (1.0 / 60.0) or globals.TickInterval()

	-- Build complete boundary map using actual stored durations
	local completeBoundaries = {}
	for tickNum = displayStartTick, maxTick do
		local boundary = tickBoundaries[tickNum]
		if boundary and type(boundary) == "table" and boundary.startTime then
			completeBoundaries[tickNum] = boundary
		elseif boundary and type(boundary) == "number" then
			completeBoundaries[tickNum] = {
				startTime = boundary,
				duration = fallbackDuration,
			}
		else
			local foundPrev = false
			for i = tickNum - 1, displayStartTick, -1 do
				if completeBoundaries[i] then
					local prevBoundary = completeBoundaries[i]
					local prevDuration = prevBoundary.duration or fallbackDuration
					completeBoundaries[tickNum] = {
						startTime = prevBoundary.startTime + (tickNum - i) * prevDuration,
						duration = prevDuration,
					}
					foundPrev = true
					break
				end
			end
			if not foundPrev then
				completeBoundaries[tickNum] = {
					startTime = dataStartTime + (tickNum - displayStartTick) * fallbackDuration,
					duration = fallbackDuration,
				}
			end
		end
	end

	-- Process each tick/frame in range
	for tickNum = displayStartTick, maxTick do
		local boundary = completeBoundaries[tickNum]
		if not boundary then
			goto continue_tick
		end

		local tickStartTime = boundary.startTime
		local duration = boundary.duration or fallbackDuration
		local nextBoundary = completeBoundaries[tickNum + 1]
		local tickEndTime = nextBoundary and nextBoundary.startTime or (tickStartTime + duration)

		-- Get screen positions of tick boundaries
		local tickStartBoardX = timeToBoardX(tickStartTime, dataStartTime)
		local tickEndBoardX = timeToBoardX(tickEndTime, dataStartTime)
		local tickStartScreenX = (tickStartBoardX - boardOffsetX) * boardZoom
		local tickEndScreenX = (tickEndBoardX - boardOffsetX) * boardZoom

		-- Skip if tick is completely off screen
		if tickEndScreenX < 0 or tickStartScreenX > screenW then
			goto continue_tick
		end

		-- Draw tick boundary line (stronger)
		if tickStartScreenX >= 0 and tickStartScreenX <= screenW then
			local intX = math.floor(tickStartScreenX + 0.5)
			draw.Color(150, 150, 200, 255)
			draw.Line(intX, rulerY, intX, rulerY + RULER_HEIGHT)

			-- Show relative position: T66 (oldest) to T1 (newest)
			local ticksFromNewest = maxTick - tickNum
			local relativeLabel = MAX_TICKS - ticksFromNewest
			local tickLabel = string.format("T%d", relativeLabel)
			if tickEndScreenX - tickStartScreenX >= 25 then
				draw.Color(200, 200, 255, 255)
				draw.Text(intX + 2, rulerY + 16, tickLabel)
			end
		end

		-- Draw subdivision lines within this tick at fixed pixel spacing
		-- Calculate first and last visible line indices (efficient at any zoom)
		local tickPixelWidth = tickEndScreenX - tickStartScreenX

		-- Only draw subdivisions if tick is wide enough for at least partial line
		if tickPixelWidth >= 1 then
			-- First visible line index: which line is at screen X=0 or tick start?
			local firstLineIdx, lastLineIdx
			if tickStartScreenX >= 0 then
				-- Tick starts on screen, first line is index 1
				firstLineIdx = 1
			else
				-- Tick starts off-screen left, calculate first visible line
				-- tickStartScreenX + (lineIdx * PIXEL_SPACING) >= 0
				-- lineIdx >= -tickStartScreenX / PIXEL_SPACING
				firstLineIdx = math.ceil(-tickStartScreenX / PIXEL_SPACING)
			end

			-- Last visible line index: which line is at screen X=screenW or tick end?
			-- tickStartScreenX + (lineIdx * PIXEL_SPACING) <= screenW
			-- lineIdx <= (screenW - tickStartScreenX) / PIXEL_SPACING
			lastLineIdx = math.floor((screenW - tickStartScreenX) / PIXEL_SPACING)

			-- Also cap at tick boundary (don't draw past tick end)
			local maxLineInTick = math.floor(tickPixelWidth / PIXEL_SPACING)
			lastLineIdx = math.min(lastLineIdx, maxLineInTick)

			-- Clamp to reasonable range
			firstLineIdx = math.max(1, firstLineIdx)
			lastLineIdx = math.min(lastLineIdx, 10000)

			for lineIdx = firstLineIdx, lastLineIdx do
				-- Calculate line position based on global timeline (not snapped tick)
				local timeIntoTick = lineIdx * timePerLine
				local lineAbsoluteTime = tickStartTime + timeIntoTick
				local lineBoardX = timeToBoardX(lineAbsoluteTime, dataStartTime)
				local lineScreenX = (lineBoardX - boardOffsetX) * boardZoom

				-- Safety check (should always be on screen now)
				if lineScreenX < 0 or lineScreenX > screenW then
					goto continue_line
				end

				local intX = math.floor(lineScreenX + 0.5)

				-- Subdivision line (lighter)
				draw.Color(100, 100, 100, 80)
				draw.Line(intX, rulerY, intX, rulerY + RULER_HEIGHT)

				-- Calculate time label (relative to tick start, preserving precision)
				local Timing = require("Profiler.timing")
				local label = Timing.FormatDuration(timeIntoTick)

				-- Draw label if space available (skip context label area)
				local textWidth = #label * 7 + 10
				local textX = intX + 2
				if textX >= lastLabelEndX + 10 and lineScreenX >= 80 and lineScreenX <= screenW - textWidth then
					draw.Color(150, 150, 150, 200)
					draw.Text(textX, rulerY + 15, label)
					lastLabelEndX = textX + textWidth
				end

				::continue_line::
			end
		end

		::continue_tick::
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

	-- Handle zoom with Q/E keys and scroll wheel - zoom towards mouse position
	local qPressed = input.IsButtonDown(KEY_Q)
	local ePressed = input.IsButtonDown(KEY_E)
	local scrollUp = input.IsButtonPressed(MOUSE_WHEEL_UP)
	local scrollDown = input.IsButtonPressed(MOUSE_WHEEL_DOWN)

	local zoomIn = qPressed or scrollUp
	local zoomOut = ePressed or scrollDown

	if zoomIn or zoomOut then
		local oldZoom = boardZoom

		if zoomIn then
			boardZoom = boardZoom * 1.1 -- Zoom in
		elseif zoomOut then
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

-- Get or create cached truncated text for a name at given pixel width
-- Uses fixed-size cache with round-robin eviction
local function getCachedTruncatedText(name, availablePixels)
	-- Quick reject: if can't fit even 1 char, return empty
	if availablePixels < 8 then
		return "", 0
	end

	-- Check if we have this name cached
	local nameCache = textCache[name]
	if not nameCache then
		-- Need to create new entry - use round-robin if at capacity
		if textCacheCount >= MAX_TEXT_CACHE_ENTRIES then
			-- Evict the oldest entry
			local evictName = textCacheOrder[nextCacheSlot]
			if evictName then
				textCache[evictName] = nil
				textCacheIndex[evictName] = nil
				textCacheCount = textCacheCount - 1
			end
		end

		-- Create new entry at current slot
		nameCache = {}
		textCache[name] = nameCache
		textCacheOrder[nextCacheSlot] = name
		textCacheIndex[name] = nextCacheSlot
		textCacheCount = textCacheCount + 1
		nextCacheSlot = nextCacheSlot + 1
		if nextCacheSlot > MAX_TEXT_CACHE_ENTRIES then
			nextCacheSlot = 1
		end
	else
		-- Move to front of LRU (optional optimization - skip for now to save CPU)
	end

	-- Check if we have this exact pixel width cached
	local cached = nameCache[availablePixels]
	if cached then
		return cached.text, cached.width
	end

	-- Need to calculate truncation
	local nameW, nameH = getTextSize(name)
	local padding = 4

	if availablePixels >= nameW + padding * 2 then
		-- Full name fits
		nameCache[availablePixels] = { text = name, width = nameW }
		return name, nameW
	end

	-- Need to truncate
	local charWidth = nameW / #name
	local maxChars = math.floor((availablePixels - padding * 2 - charWidth * 2) / charWidth)

	if maxChars <= 0 then
		-- Can't fit even truncated
		nameCache[availablePixels] = { text = "", width = 0 }
		return "", 0
	end

	local truncated = name:sub(1, maxChars) .. ".."
	local truncatedW = getTextSize(truncated)
	nameCache[availablePixels] = { text = truncated, width = truncatedW }

	return truncated, truncatedW
end

-- Per-frame text cache update (processes pending updates)
local function updateTextCache()
	-- Reset per-frame counter
	updatesThisFrame = 0
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

	hoveredFunc = nil
	currentTopBarHeight = topBarHeight or 60

	local screenW, screenH = draw.GetScreenSize()

	draw.Color(20, 20, 20, 240)
	draw.FilledRect(0, topBarHeight, screenW, screenH)

	local MAX_TICKS = 66
	local tickInterval = globals.TickInterval()
	local currentTime = os.clock()

	-- Extract both contexts
	local contexts = profilerData.contexts
	if not contexts then
		return
	end

	local tickContext = contexts.TICK
	local frameContext = contexts.FRAME

	-- Helper to process a context's data
	local function processContextData(ctx)
		local minTick = math.huge
		local maxTick = -math.huge

		if ctx.scriptTimelines then
			for _, scriptData in pairs(ctx.scriptTimelines) do
				if scriptData.functions then
					for _, func in ipairs(scriptData.functions) do
						if func.startTick then
							minTick = math.min(minTick, func.startTick)
							maxTick = math.max(maxTick, func.startTick)
						end
						if func.endTick then
							maxTick = math.max(maxTick, func.endTick)
						end
					end
				end
			end
		end

		return minTick, maxTick
	end

	-- Helper to calculate time bounds for context
	local function calculateTimeBounds(ctx, minTick, maxTick)
		local validTickStart = maxTick - MAX_TICKS + 1
		if minTick == math.huge then
			validTickStart = 0
		end

		local dataStartTime = math.huge
		local dataEndTime = -math.huge
		local tickBoundaries = {}

		if ctx.callbackBoundaries then
			for tickNum, boundary in pairs(ctx.callbackBoundaries) do
				if tickNum >= validTickStart then
					local startTime, duration
					if type(boundary) == "table" and boundary.startTime then
						startTime = boundary.startTime
						duration = boundary.duration
						tickBoundaries[tickNum] = boundary
					elseif type(boundary) == "number" then
						startTime = boundary
						duration = nil
						tickBoundaries[tickNum] = { startTime = boundary, duration = nil }
					else
						goto continue_boundary
					end

					dataStartTime = math.min(dataStartTime, startTime)
					local endTime = startTime + (duration or 0)
					dataEndTime = math.max(dataEndTime, endTime)
				end
				::continue_boundary::
			end
		end

		if ctx.scriptTimelines then
			for _, scriptData in pairs(ctx.scriptTimelines) do
				if scriptData.functions then
					for _, func in ipairs(scriptData.functions) do
						local funcTick = func.startTick or func.endTick
						if funcTick and funcTick >= validTickStart then
							if func.startTime and func.endTime then
								dataStartTime = math.min(dataStartTime, func.startTime)
								dataEndTime = math.max(dataEndTime, func.endTime)

								if func.startTick and func.startTick >= validTickStart then
									if not tickBoundaries[func.startTick] then
										tickBoundaries[func.startTick] = func.startTime
									end
								end
								if func.endTick and func.endTick >= validTickStart then
									if not tickBoundaries[func.endTick] then
										tickBoundaries[func.endTick] = func.endTime
									end
								end
							end
						end
					end
				end
			end
		end

		if dataStartTime == math.huge then
			dataStartTime = currentTime - (MAX_TICKS * tickInterval)
			dataEndTime = currentTime
			minTick = globals.TickCount() - MAX_TICKS
			maxTick = globals.TickCount()
		end

		return validTickStart, dataStartTime, dataEndTime, tickBoundaries, minTick, maxTick
	end

	-- Process TICK context
	local tickMinTick, tickMaxTick = processContextData(tickContext)
	local tickValidStart, tickDataStart, tickDataEnd, tickBoundaries, tickMinTick, tickMaxTick =
		calculateTimeBounds(tickContext, tickMinTick, tickMaxTick)

	-- Process FRAME context
	local frameMinTick, frameMaxTick = processContextData(frameContext)
	local frameValidStart, frameDataStart, frameDataEnd, frameBoundaries, frameMinTick, frameMaxTick =
		calculateTimeBounds(frameContext, frameMinTick, frameMaxTick)

	-- Auto-scroll
	local UITop = require("Profiler.ui_top")
	if not UITop.IsPaused() then
		local visibleTimeWidth = screenW / (TIME_SCALE * boardZoom)
		local tickTargetOffset = (tickDataEnd - tickDataStart) - visibleTimeWidth
		if tickTargetOffset > 0 then
			boardOffsetX = tickTargetOffset * TIME_SCALE
		else
			boardOffsetX = 0
		end
	end

	-- RENDER TICK CONTEXT
	local tickRulerY = topBarHeight
	drawTimeRuler(
		screenW,
		screenH,
		tickRulerY,
		tickDataStart,
		tickDataEnd,
		tickBoundaries,
		tickMinTick,
		tickMaxTick,
		"TICK"
	)

	local tickBoardY = 0
	local tickContentBottom = tickRulerY + RULER_HEIGHT

	if tickContext.scriptTimelines then
		for scriptName, scriptData in pairs(tickContext.scriptTimelines) do
			if scriptData.functions and #scriptData.functions > 0 then
				local validFunctions = {}
				for _, func in ipairs(scriptData.functions) do
					local funcTick = func.startTick or func.endTick
					if funcTick and funcTick >= tickValidStart then
						table.insert(validFunctions, func)
					end
				end

				if #validFunctions > 0 then
					local newTickBoardY = drawScriptOnBoard(
						scriptName,
						validFunctions,
						tickBoardY,
						tickDataStart,
						tickDataEnd,
						screenW,
						screenH
					)
					-- Validate return value
					if newTickBoardY and type(newTickBoardY) == "number" and newTickBoardY == newTickBoardY then
						tickBoardY = newTickBoardY
						-- Track lowest point
						local scriptBottom = tickRulerY + RULER_HEIGHT + tickBoardY
						if scriptBottom == scriptBottom then
							tickContentBottom = math.max(tickContentBottom, scriptBottom)
						end
					end
				end
			end
		end
	end

	-- Validate tickContentBottom before using
	if tickContentBottom ~= tickContentBottom or tickContentBottom == math.huge or tickContentBottom == -math.huge then
		tickContentBottom = tickRulerY + RULER_HEIGHT
	end

	-- RENDER FRAME CONTEXT below TICK content
	local frameRulerY = tickContentBottom + 10
	drawTimeRuler(
		screenW,
		screenH,
		frameRulerY,
		frameDataStart,
		frameDataEnd,
		frameBoundaries,
		frameMinTick,
		frameMaxTick,
		"FRAME"
	)

	local frameBoardY = 0

	if frameContext.scriptTimelines then
		for scriptName, scriptData in pairs(frameContext.scriptTimelines) do
			if scriptData.functions and #scriptData.functions > 0 then
				local validFunctions = {}
				for _, func in ipairs(scriptData.functions) do
					local funcTick = func.startTick or func.endTick
					if funcTick and funcTick >= frameValidStart then
						table.insert(validFunctions, func)
					end
				end

				if #validFunctions > 0 then
					-- Temporarily adjust currentTopBarHeight for frame context
					local savedTopBar = currentTopBarHeight
					currentTopBarHeight = frameRulerY

					frameBoardY = drawScriptOnBoard(
						scriptName,
						validFunctions,
						frameBoardY,
						frameDataStart,
						frameDataEnd,
						screenW,
						screenH
					)

					currentTopBarHeight = savedTopBar
				end
			end
		end
	end

	-- Draw hover tooltip if function is hovered
	if hoveredFunc and input and input.GetMousePos then
		local pos = input.GetMousePos()
		local mx, my = pos[1] or 0, pos[2] or 0
		local tooltipX = mx + 15
		local tooltipY = my + 15
		local tooltipW = 300
		local tooltipH = 60

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

		local startRaw = hoveredFunc.startTime
		local endRaw = hoveredFunc.endTime
		local durationSec = endRaw - startRaw

		local Timing = require("Profiler.timing")
		local durationText = "Duration: " .. Timing.FormatDuration(durationSec)

		draw.Color(255, 255, 150, 255)
		draw.Text(textX, textY + 18, durationText)

		local memKb = hoveredFunc.memDelta or 0
		local memMb = memKb / 1024
		local memText = memMb >= 1 and string.format("Memory: %.2f MB", memMb)
			or string.format("Memory: %.1f KB", memKb)
		draw.Color(150, 255, 150, 255)
		draw.Text(textX, textY + 36, memText)
	end

	-- Draw info overlay
	draw.Color(255, 255, 255, 255)
	draw.Text(10, screenH - 125, "DUAL CONTEXT MODE")
	draw.Text(10, screenH - 110, string.format("TICK: %.3fs - %.3fs", tickDataStart, tickDataEnd))
	draw.Text(10, screenH - 95, string.format("FRAME: %.3fs - %.3fs", frameDataStart, frameDataEnd))
	draw.Text(10, screenH - 80, string.format("Board Zoom: %.2fx", boardZoom))
	draw.Text(10, screenH - 65, string.format("Board Offset: X=%.0f Y=%.0f", boardOffsetX, boardOffsetY))
	draw.Text(10, screenH - 50, string.format("Time Scale: %.1f px/s", TIME_SCALE))
	draw.Text(10, screenH - 35, "Drag=Move Board, Q=Zoom In, E=Zoom Out")
	draw.Text(10, screenH - 20, string.format("Dragging: %s", tostring(isDragging)))

	-- Handle input
	handleBoardInput(screenW, screenH, topBarHeight)

	-- Process text update queue (per-frame limited updates)
	updateTextCache()
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
