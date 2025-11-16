--[[
    UI Render Module - Clean Dual-Zone Profiler Rendering
    Separates tick work and frame work with independent rulers
]]

local Shared = require("Profiler.Shared")

local UIRender = {}

-- Constants
local TIME_SCALE = 50000 -- 1ms = 50px
local RULER_HEIGHT = 30
local ZONE_LABEL_HEIGHT = 20
local WORK_HEIGHT = 18
local WORK_INDENT = 20
local PROCESS_SPACING = 25

-- Helper: timeToBoardX
local function timeToBoardX(time, origin)
	return (time - origin) * TIME_SCALE
end

-- Clamp coordinates to valid integer range
local function clampCoord(value)
	if not value or value ~= value then
		return 0
	end -- NaN check
	if value == math.huge or value == -math.huge then
		return 0
	end -- Infinity check
	return math.max(-100000, math.min(100000, math.floor(value + 0.5)))
end

-- Draw ruler for a zone (tick or frame)
local function drawRuler(mode, screenX, screenY, screenW, dataStart, dataEnd, frameTime, zoom, offsetX)
	if not draw then
		return
	end

	-- Background (clamped)
	local x1 = clampCoord(screenX)
	local y1 = clampCoord(screenY)
	local x2 = clampCoord(screenX + screenW)
	local y2 = clampCoord(screenY + RULER_HEIGHT)

	draw.Color(30, 30, 30, 255)
	draw.FilledRect(x1, y1, x2, y2)

	-- Frame boundaries (T0, T1 or F0, F1)
	local firstBoundary = math.ceil(dataStart / frameTime) * frameTime
	local boundaryTime = firstBoundary
	local index = 0

	while boundaryTime <= dataEnd and index < 100 do
		local boardX = timeToBoardX(boundaryTime, dataStart)
		local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)

		if screenXPos >= screenX - 10 and screenXPos <= screenX + screenW + 10 then
			local intX = clampCoord(screenXPos)
			local lineY1 = clampCoord(screenY)
			local lineY2 = clampCoord(screenY + RULER_HEIGHT)

			-- Boundary line
			draw.Color(150, 150, 200, 255)
			draw.Line(intX, lineY1, intX, lineY2)

			-- Label
			local label = mode == "tick" and string.format("T%d", index) or string.format("F%d", index)
			draw.Color(200, 200, 255, 255)
			draw.Text(intX + 2, lineY1 + 2, label)
		end

		boundaryTime = boundaryTime + frameTime
		index = index + 1
	end

	-- Time subdivisions (clean intervals)
	local minPixelSpacing = 40
	local targetPixelSpacing = 60
	local bestInterval = 0.0001
	local base = 0.0001

	while base < 10.0 do
		for _, scale in ipairs({ 1, 2, 5 }) do
			local mag = base * scale
			local pixelSpacing = mag * TIME_SCALE * zoom
			if pixelSpacing >= minPixelSpacing and pixelSpacing <= 120 then
				if
					math.abs(pixelSpacing - targetPixelSpacing)
					< math.abs(bestInterval * TIME_SCALE * zoom - targetPixelSpacing)
				then
					bestInterval = mag
				end
			end
		end
		base = base * 10
	end

	if bestInterval * TIME_SCALE * zoom >= minPixelSpacing then
		local firstMark = math.ceil(dataStart / bestInterval) * bestInterval
		local time = firstMark

		while time <= dataEnd do
			local boardX = timeToBoardX(time, dataStart)
			local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)

			if screenXPos >= screenX - 10 and screenXPos <= screenX + screenW + 10 then
				local intX = clampCoord(screenXPos)
				local lineY1 = clampCoord(screenY)
				local lineY2 = clampCoord(screenY + RULER_HEIGHT)

				-- Subdivision line
				draw.Color(100, 100, 100, 120)
				draw.Line(intX, lineY1, intX, lineY2)

				-- Label
				local relTime = time - dataStart
				local label
				if bestInterval >= 0.01 then
					label = string.format("%dms", math.floor(relTime * 1000 + 0.5))
				else
					label = string.format("%dµs", math.floor(relTime * 1000000 + 0.5))
				end

				draw.Color(180, 180, 200, 220)
				draw.Text(intX + 2, lineY1 + 15, label)
			end

			time = time + bestInterval
		end
	end
end

-- Draw work bar hierarchically
local function drawWork(work, depth, screenX, screenY, dataStart, zoom, offsetX, zoneEndY)
	if not draw or not work.startTime or not work.endTime then
		return
	end

	local boardX = timeToBoardX(work.startTime, dataStart)
	local boardWidth = timeToBoardX(work.endTime, dataStart) - boardX

	local screenXPos = screenX + (boardX * zoom) - (offsetX * zoom)
	local screenWidth = boardWidth * zoom

	-- Only draw if visible
	if screenXPos + screenWidth < screenX or screenXPos > screenX + 1920 then
		return
	end

	-- Indent based on depth
	local indentX = depth * WORK_INDENT

	-- Work bar
	draw.Color(80, 200, 120, 255)
	draw.FilledRect(
		math.floor(screenXPos + indentX),
		math.floor(screenY),
		math.floor(screenXPos + screenWidth),
		math.floor(screenY + WORK_HEIGHT)
	)

	-- Border
	draw.Color(255, 255, 255, 200)
	draw.OutlinedRect(
		math.floor(screenXPos + indentX),
		math.floor(screenY),
		math.floor(screenXPos + screenWidth),
		math.floor(screenY + WORK_HEIGHT)
	)

	-- Label
	if screenWidth > 30 then
		draw.Color(255, 255, 255, 255)
		draw.Text(math.floor(screenXPos + indentX + 2), math.floor(screenY + 2), work.name or "Work")
	end

	-- Grid line extension (only within zone)
	if screenY + WORK_HEIGHT < zoneEndY then
		local lineX = clampCoord(screenXPos)
		local lineY1 = clampCoord(screenY + WORK_HEIGHT)
		local lineY2 = clampCoord(zoneEndY)

		draw.Color(80, 80, 80, 30)
		draw.Line(lineX, lineY1, lineX, lineY2)
	end
end

-- Render a zone (tick or frame)
function UIRender.DrawZone(
	zone,
	mode,
	screenX,
	screenY,
	screenW,
	screenH,
	dataStart,
	dataEnd,
	frameTime,
	zoom,
	offsetX,
	offsetY
)
	if not draw or not zone then
		return
	end

	-- Apply vertical offset for scrolling
	local adjustedScreenY = screenY - (offsetY * zoom)

	-- Clamp all coordinates
	local x1 = clampCoord(screenX)
	local y1 = clampCoord(adjustedScreenY)
	local x2 = clampCoord(screenX + screenW)
	local y2 = clampCoord(adjustedScreenY + zone.height)
	local labelY2 = clampCoord(adjustedScreenY + ZONE_LABEL_HEIGHT)

	-- Zone background
	draw.Color(25, 25, 25, 255)
	draw.FilledRect(x1, y1, x2, y2)

	-- Zone label
	draw.Color(40, 40, 40, 255)
	draw.FilledRect(x1, y1, x2, labelY2)
	draw.Color(200, 200, 220, 255)
	local label = mode == "tick" and "TICK-BASED WORK" or "FRAME-BASED WORK"
	draw.Text(x1 + 10, y1 + 4, label)

	-- Ruler
	drawRuler(mode, screenX, adjustedScreenY + ZONE_LABEL_HEIGHT, screenW, dataStart, dataEnd, frameTime, zoom, offsetX)

	-- Work items (hierarchical)
	if zone.work then
		for _, item in ipairs(zone.work) do
			local workY = adjustedScreenY + ZONE_LABEL_HEIGHT + RULER_HEIGHT + (item.y - zone.workY)
			drawWork(item.work, item.depth, screenX, workY, dataStart, zoom, offsetX, adjustedScreenY + zone.height)
		end
	end

	-- Zone border
	local borderX1 = clampCoord(screenX)
	local borderY1 = clampCoord(adjustedScreenY)
	local borderX2 = clampCoord(screenX + screenW)
	local borderY2 = clampCoord(adjustedScreenY + zone.height)

	draw.Color(60, 60, 80, 255)
	draw.OutlinedRect(borderX1, borderY1, borderX2, borderY2)
end

return UIRender
