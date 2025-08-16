--[[
    Simple UI Body Module - Rewritten for consistency
    Fixed coordinate system with time-based horizontal scaling
]]

-- Imports
local G = require("Profiler.globals")

-- Module declaration
local UIBody = {}

-- Constants
local BASE_FUNCTION_HEIGHT = 20
local BASE_FUNCTION_SPACING = 2
local BASE_SCRIPT_HEADER_HEIGHT = 25
local BASE_SCRIPT_SPACING = 10

-- Global state (retained mode)
local offsetX = 0 -- Horizontal offset of the profiler board
local offsetY = 0 -- Vertical offset of the profiler board
local timeScale = 100.0 -- Pixels per second (horizontal zoom)
local verticalScale = 1.0 -- Vertical scaling factor
local isDragging = false
local lastMouseX, lastMouseY = 0, 0

-- External APIs
local draw = _G.draw
local input = _G.input
local MOUSE_LEFT = _G.MOUSE_LEFT or 107
local KEY_Q = _G.KEY_Q or 18
local KEY_E = _G.KEY_E or 20

-- Helper functions
local function getTime()
	return (_G.globals and _G.globals.RealTime and _G.globals.RealTime()) or 0
end

local function timeToPixel(time, startTime)
	return (time - startTime) * timeScale
end

local function pixelToTime(pixel, startTime)
	return startTime + (pixel / timeScale)
end

local function drawFunction(func, x, y, width)
    if not func.startTime or not func.endTime or not draw then
        return
    end
    
    local functionHeight = BASE_FUNCTION_HEIGHT * verticalScale
    
    -- Draw function bar
    draw.Color(100, 150, 200, 180)
    draw.FilledRect(math.floor(x), math.floor(y), math.floor(x + width), math.floor(y + functionHeight))
    
    -- Draw border
    draw.Color(255, 255, 255, 100)
    draw.OutlinedRect(math.floor(x), math.floor(y), math.floor(x + width), math.floor(y + functionHeight))
    
    -- Draw function name if it fits
    local name = func.name or "unknown"
    if width > 50 and functionHeight > 12 then
        draw.Color(255, 255, 255, 255)
        draw.Text(math.floor(x + 4), math.floor(y + 2), name)
    end
    
    -- Draw duration if there's space
    if width > 120 and functionHeight > 24 then
        local duration = (func.endTime - func.startTime) * 1000 -- ms
        local durationText = string.format("%.3fms", duration)
        draw.Color(255, 255, 100, 255)
        draw.Text(math.floor(x + 4), math.floor(y + functionHeight - 12), durationText)
    end
end

local function drawScript(scriptName, functions, startY, dataStartTime, dataEndTime)
	if not draw then
		return startY
	end

	local currentY = startY

	-- Calculate script width by finding earliest and latest function times
	local scriptStartTime = math.huge
	local scriptEndTime = -math.huge

	for _, func in ipairs(functions) do
		if func.startTime and func.endTime then
			scriptStartTime = math.min(scriptStartTime, func.startTime)
			scriptEndTime = math.max(scriptEndTime, func.endTime)
		end
	end

	local scriptHeaderHeight = BASE_SCRIPT_HEADER_HEIGHT * verticalScale
	local functionSpacing = BASE_FUNCTION_SPACING * verticalScale

	-- Draw script header spanning the entire script duration
	if scriptStartTime ~= math.huge and scriptEndTime ~= -math.huge then
		local headerX = timeToPixel(scriptStartTime, dataStartTime) - offsetX
		local headerWidth = timeToPixel(scriptEndTime, dataStartTime) - timeToPixel(scriptStartTime, dataStartTime)

		-- Draw header background spanning script duration
		draw.Color(60, 120, 60, 200)
		draw.FilledRect(
			math.floor(headerX),
			math.floor(currentY),
			math.floor(headerX + headerWidth),
			math.floor(currentY + scriptHeaderHeight)
		)

		-- Draw header border
		draw.Color(255, 255, 255, 200)
		draw.OutlinedRect(
			math.floor(headerX),
			math.floor(currentY),
			math.floor(headerX + headerWidth),
			math.floor(currentY + scriptHeaderHeight)
		)

		-- Draw script name and info only if header is visible and tall enough
		if headerX + headerWidth > 0 and headerX < 2000 and scriptHeaderHeight > 12 then
			draw.Color(255, 255, 255, 255)
			draw.Text(math.floor(headerX + 4), math.floor(currentY + 4), scriptName)
			if scriptHeaderHeight > 20 then
				draw.Text(math.floor(headerX + 4), math.floor(currentY + scriptHeaderHeight - 12), string.format("(%d functions)", #functions))
			end
		end
	end

	currentY = currentY + scriptHeaderHeight + functionSpacing

	-- Draw functions stacked vertically
	for _, func in ipairs(functions) do
		if func.startTime and func.endTime then
			local x = timeToPixel(func.startTime, dataStartTime) - offsetX
			local width = timeToPixel(func.endTime, dataStartTime) - timeToPixel(func.startTime, dataStartTime)

			-- Only draw if visible on screen
			if x + width > 0 and x < 2000 then -- Assume 2000px max screen width
				drawFunction(func, x, currentY - offsetY, width)
			end
		end

		currentY = currentY + (BASE_FUNCTION_HEIGHT * verticalScale) + (BASE_FUNCTION_SPACING * verticalScale)
	end

	return currentY + (BASE_SCRIPT_SPACING * verticalScale)
end

local function handleInput(screenW, screenH, topBarHeight)
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

	-- Handle dragging
	local currentlyDragging = input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)

	if currentlyDragging and not isDragging then
		-- Start drag
		isDragging = true
		lastMouseX = mx
		lastMouseY = bodyMy
		print("🎯 DRAG START")
	elseif currentlyDragging and isDragging then
		-- Continue drag - move the profiler board
		local deltaX = mx - lastMouseX
		local deltaY = bodyMy - lastMouseY

		offsetX = offsetX - deltaX
		offsetY = offsetY - deltaY

		print(string.format("🎯 DRAGGING: offsetX=%.1f, offsetY=%.1f", offsetX, offsetY))

		lastMouseX = mx
		lastMouseY = bodyMy
	elseif not currentlyDragging and isDragging then
		-- End drag
		isDragging = false
		print("🎯 DRAG END")
	end

	    -- Handle zoom with Q/E keys - simple scaling
    if input.IsButtonDown then
        local qPressed = input.IsButtonDown(KEY_Q)
        local ePressed = input.IsButtonDown(KEY_E)
        
        if qPressed then
            timeScale = timeScale * 1.02 -- Zoom in horizontally (slower)
            verticalScale = verticalScale * 1.02 -- Zoom in vertically
            print(string.format("🔍 ZOOM IN: timeScale=%.1f, verticalScale=%.2f", timeScale, verticalScale))
        elseif ePressed then
            timeScale = timeScale / 1.02 -- Zoom out horizontally (slower)
            verticalScale = verticalScale / 1.02 -- Zoom out vertically
            print(string.format("🔍 ZOOM OUT: timeScale=%.1f, verticalScale=%.2f", timeScale, verticalScale))
        end
        
        -- Clamp zoom
        timeScale = math.max(1.0, math.min(10000.0, timeScale))
        verticalScale = math.max(0.1, math.min(10.0, verticalScale))
    end
end

-- Public API
function UIBody.Initialize()
	offsetX = 0
	offsetY = 0
	timeScale = 100.0
	verticalScale = 1.0
	isDragging = false
end

function UIBody.SetVisible(visible)
	-- Simple visibility toggle
end

function UIBody.IsVisible()
	return true -- Always visible when called
end

function UIBody.Draw(profilerData, topBarHeight)
	if not draw or not profilerData then
		return
	end

	local screenW, screenH = draw.GetScreenSize()

	-- Draw background
	draw.Color(20, 20, 20, 240)
	draw.FilledRect(0, topBarHeight, screenW, screenH)

	-- Calculate time bounds from all data
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

	-- Fallback if no data
	if dataStartTime == math.huge then
		dataStartTime = getTime() - 5
		dataEndTime = getTime()
	end

	local currentY = topBarHeight + 10

	-- Draw each script's functions
	if profilerData.scriptTimelines then
		for scriptName, scriptData in pairs(profilerData.scriptTimelines) do
			if scriptData.functions and #scriptData.functions > 0 then
				currentY = drawScript(scriptName, scriptData.functions, currentY, dataStartTime, dataEndTime)
			end
		end
	end

	-- Draw info overlay
	draw.Color(255, 255, 255, 255)
	draw.Text(10, screenH - 95, string.format("Time Scale: %.1f px/s", timeScale))
	draw.Text(10, screenH - 80, string.format("Vertical Scale: %.2fx", verticalScale))
	draw.Text(10, screenH - 65, string.format("Offset: X=%.0f Y=%.0f", offsetX, offsetY))
	draw.Text(10, screenH - 50, string.format("Time Range: %.3fs - %.3fs", dataStartTime, dataEndTime))
	draw.Text(10, screenH - 35, "Drag=Pan, Q=Zoom In, E=Zoom Out")
	draw.Text(10, screenH - 20, string.format("Dragging: %s", tostring(isDragging)))

	-- Handle input
	handleInput(screenW, screenH, topBarHeight)
end

-- Camera controls
function UIBody.ResetCamera()
	offsetX = 0
	offsetY = 0
	timeScale = 100.0
end

function UIBody.SetZoom(newZoom)
	timeScale = math.max(1.0, math.min(10000.0, newZoom))
end

function UIBody.GetZoom()
	return timeScale
end

return UIBody
