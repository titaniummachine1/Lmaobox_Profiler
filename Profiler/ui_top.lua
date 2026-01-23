--[[
    UI Top Module - Timeline and Controls
    Handles the top bar with frame timeline and control buttons
    Used by: profiler.lua
]]

-- Imports
local Shared = require("Profiler.Shared") --[[ Imported by: profiler ]]
local config = require("Profiler.config")

-- globals is a global table provided by the environment (RealTime, TickInterval, etc.)

-- Module declaration
local UITop = {}

-- Local constants / utilities -------- (Lua 5.4 compatible)
local TIMELINE_HEIGHT = 60 -- Increased height for better button fit
local FRAME_RECORDING_TIME = 5 -- 5 seconds of frames (reduced for stability)
local BUTTON_WIDTH = 70 -- Slightly smaller buttons
local BUTTON_HEIGHT = 18
local BUTTON_SPACING = 3
local MAX_FRAMES = 150 -- Reduced frame storage

-- Global variables for retained mode (not local)
frames = frames or {} -- { dt = tickInterval, timestamp = realTime }
selectedFrameIndex = selectedFrameIndex or nil
isPaused = isPaused or false
isCapturingKey = isCapturingKey or false
bodyKey = bodyKey or nil
totalRecordedTime = totalRecordedTime or 0
local lastFrameTimestamp = 0

-- Key constants with fallbacks (Lua 5.4 compatible)
local KEY_P = KEY_P or 26
local MOUSE_LEFT = MOUSE_LEFT or 107

-- Click state tracking (global for retained mode)
clickState = clickState or {}
keyState = keyState or {}

-- Font (global for retained mode)
topBarFont = topBarFont or nil

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
	if not topBarFont and draw and draw.CreateFont then
		-- Create a large, crisp, readable font
		topBarFont = draw.CreateFont("Verdana", 16, 800) -- Much larger and bolder
	end
end

-- Remove these functions - use globals.RealTime() and globals.TickInterval() directly

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

-- Smart click handling (prevents double clicks, captures hold-to-press)
local function consumeClick(id, hovered)
	if not input then
		return false
	end

	local currentlyDown = hovered and input.IsButtonDown and input.IsButtonDown(MOUSE_LEFT)
	local wasDown = clickState[id] or false

	-- Smart detection: capture click OR sudden hold
	if currentlyDown and not wasDown then
		-- Either clicked OR started holding (both count as press)
		clickState[id] = true
		return true
	elseif not currentlyDown and wasDown then
		-- Released - reset state for next interaction
		clickState[id] = false
	end

	return false
end

-- Smart key handling (prevents double presses, captures hold-to-press)
local function consumeKeyPress(keyId)
	if not input then
		return false
	end

	local currentlyDown = input.IsButtonDown and input.IsButtonDown(keyId)
	local wasDown = keyState[keyId] or false

	-- Smart detection: capture press OR sudden hold
	if currentlyDown and not wasDown then
		-- Either pressed OR started holding (both count as press)
		keyState[keyId] = true
		return true
	elseif not currentlyDown and wasDown then
		-- Released - reset state for next interaction
		keyState[keyId] = false
	end

	return false
end

-- Get key name for display
local function getKeyName(keyId)
	if keyId >= 11 and keyId <= 36 then
		return string.char(string.byte("A") + (keyId - 11))
	end
	if keyId >= 2 and keyId <= 10 then
		local d = (keyId - 1) % 10
		return tostring(d)
	end

	local names = {
		[65] = "SPACE",
		[64] = "ENTER",
		[67] = "TAB",
		[70] = "ESC",
		[79] = "LSHIFT",
		[80] = "RSHIFT",
		[83] = "LCTRL",
		[84] = "RCTRL",
		[81] = "LALT",
		[82] = "RALT",
	}

	if names[keyId] then
		return names[keyId]
	end
	if keyId >= 92 and keyId <= 103 then
		return "F" .. tostring(keyId - 91)
	end
	return tostring(keyId)
end

-- Update frame recording
local function updateFrameRecording()
	if isPaused then
		return
	end

	local currentTime = globals.RealTime()
	local tickInterval = globals.TickInterval()
	assert(tickInterval and tickInterval > 0, "updateFrameRecording: invalid tick interval")

	if currentTime - lastFrameTimestamp < tickInterval then
		return
	end

	lastFrameTimestamp = currentTime
	local dt = tickInterval
	local timestamp = currentTime

	-- Add new frame
	table.insert(frames, {
		dt = dt,
		timestamp = timestamp,
		index = #frames + 1,
	})

	totalRecordedTime = totalRecordedTime + dt

	-- Remove frames older than FRAME_RECORDING_TIME seconds
	while totalRecordedTime > FRAME_RECORDING_TIME and #frames > 0 do
		local removedFrame = table.remove(frames, 1)
		totalRecordedTime = totalRecordedTime - removedFrame.dt

		-- Adjust selected frame index
		if selectedFrameIndex then
			selectedFrameIndex = selectedFrameIndex - 1
			if selectedFrameIndex <= 0 then
				selectedFrameIndex = nil
			end
		end
	end

	-- Also enforce MAX_FRAMES limit for performance
	while #frames > MAX_FRAMES do
		local removedFrame = table.remove(frames, 1)
		totalRecordedTime = totalRecordedTime - removedFrame.dt

		-- Adjust selected frame index
		if selectedFrameIndex then
			selectedFrameIndex = selectedFrameIndex - 1
			if selectedFrameIndex <= 0 then
				selectedFrameIndex = nil
			end
		end
	end

	-- Auto-select latest frame if none selected
	if not selectedFrameIndex and #frames > 0 then
		selectedFrameIndex = #frames
	end
end

-- Draw frame pillars (ACTUAL PILLARS - thin and tall)
local function drawFramePillars(screenW)
	if #frames == 0 then
		return
	end

	local maxMs = 33.3 -- ~30 FPS baseline
	local infoWidth = 100 -- Space for left side info
	local buttonSpace = BUTTON_WIDTH + 20 -- Space for right side buttons
	local frameAreaWidth = screenW - infoWidth - buttonSpace
	local frameAreaStart = infoWidth

	if frameAreaWidth <= 0 then
		return -- Not enough space
	end

	-- PILLAR SETUP: Fixed narrow width, spacing controlled
	local pillarWidth = 3 -- Thin pillars!
	local pillarSpacing = 2 -- Gap between pillars
	local totalPillarSpace = pillarWidth + pillarSpacing
	local maxPillars = math.floor(frameAreaWidth / totalPillarSpace)

	-- Only show recent frames that fit
	local startFrame = math.max(1, #frames - maxPillars + 1)
	local x = frameAreaStart

	-- Draw frames as thin pillars (newest frames from left to right)
	for i = startFrame, #frames do
		local frame = frames[i]

		-- Safe validation and calculations
		if frame and frame.dt then
			local ms = frame.dt * 1000

			-- Only proceed if ms is valid
			if ms == ms and ms ~= math.huge and ms ~= -math.huge then
				-- Height based on frame time (taller = slower frame)
				local heightNorm = clamp(ms / maxMs, 0, 1)
				if heightNorm ~= heightNorm then
					heightNorm = 0
				end
				local height = math.max(4, safeCoord(heightNorm * (TIMELINE_HEIGHT - 10)))

				-- Color based on performance (green=good, yellow=ok, red=bad)
				local r, g, b
				if heightNorm < 0.3 then
					-- Good performance - green
					r, g, b = 50, 255, 50
				elseif heightNorm < 0.7 then
					-- OK performance - yellow
					r, g, b = 255, 255, 50
				else
					-- Bad performance - red
					r, g, b = 255, 50, 50
				end

				-- Highlight selected frame
				if selectedFrameIndex == i then
					r = math.min(255, r + 50)
					g = math.min(255, g + 50)
					b = math.min(255, b + 50)
				end

				-- Draw thin pillar
				local rectX = safeCoord(x)
				local rectY = safeCoord(TIMELINE_HEIGHT - height - 2)

				if draw and height > 0 and rectX + pillarWidth < screenW - buttonSpace then
					draw.Color(r, g, b, 255)
					safeFilledRect(rectX, rectY, rectX + pillarWidth, TIMELINE_HEIGHT - 2)

					-- Store click region for interaction
					frame._clickRegion = {
						x = rectX,
						y = rectY,
						w = pillarWidth,
						h = height + 2,
					}
				end

				x = x + totalPillarSpace
			end
		end
	end
end

-- Draw control buttons (stacked vertically on right)
local function drawControls(screenW)
	local buttonX = screenW - BUTTON_WIDTH - 8
	local pauseY = 4
	local bindY = pauseY + BUTTON_HEIGHT + BUTTON_SPACING

	-- Pause/Resume button
	local pauseLabel = isPaused and "Resume [P]" or "Pause [P]"

	if draw then
		-- Pause button background
		draw.Color(45, 45, 45, 255)
		safeFilledRect(buttonX, pauseY, buttonX + BUTTON_WIDTH, pauseY + BUTTON_HEIGHT)
		draw.Color(110, 110, 110, 255)
		draw.OutlinedRect(buttonX, pauseY, buttonX + BUTTON_WIDTH, pauseY + BUTTON_HEIGHT)

		-- Pause button text (integer coordinates)
		draw.Color(230, 230, 230, 255)
		draw.Text(math.floor(buttonX + 4), math.floor(pauseY + 2), pauseLabel)

		-- Keybind button background
		draw.Color(45, 45, 45, 255)
		safeFilledRect(buttonX, bindY, buttonX + BUTTON_WIDTH, bindY + BUTTON_HEIGHT)
		draw.Color(110, 110, 110, 255)
		draw.OutlinedRect(buttonX, bindY, buttonX + BUTTON_WIDTH, bindY + BUTTON_HEIGHT)

		-- Keybind button text (integer coordinates)
		local bindLabel = isCapturingKey and "Press key..." or ("Bind [" .. getKeyName(bodyKey or 25) .. "]")
		draw.Color(230, 230, 230, 255)
		draw.Text(math.floor(buttonX + 4), math.floor(bindY + 2), bindLabel)
	end

	return buttonX, pauseY, bindY
end

-- Handle input
local function handleInput(screenW, buttonX, pauseY, bindY)
	if not input or not input.GetMousePos then
		return
	end

	local pos = input.GetMousePos()
	local mx, my = pos[1] or 0, pos[2] or 0

	-- Button clicks
	local hoveredPause = mx >= buttonX
		and mx <= buttonX + BUTTON_WIDTH
		and my >= pauseY
		and my <= pauseY + BUTTON_HEIGHT
	local hoveredBind = mx >= buttonX and mx <= buttonX + BUTTON_WIDTH and my >= bindY and my <= bindY + BUTTON_HEIGHT

	if consumeClick("pause_button", hoveredPause) then
		isPaused = not isPaused
		-- Sync pause state with microprofiler
		local MicroProfiler = require("Profiler.microprofiler")
		MicroProfiler.SetPaused(isPaused)
		return -- Don't process frame selection when clicking buttons
	end

	if consumeClick("bind_button", hoveredBind) then
		isCapturingKey = true
		return
	end

	-- Frame selection (only when paused and not clicking buttons)
	if isPaused and my >= 0 and my <= TIMELINE_HEIGHT and not hoveredPause and not hoveredBind then
		if consumeClick("frame_select", true) then
			-- Find clicked frame and center body on its time
			for i, frame in ipairs(frames) do
				if frame._clickRegion then
					local region = frame._clickRegion
					if
						mx >= region.x
						and mx <= region.x + region.w
						and my >= region.y
						and my <= region.y + region.h
					then
						selectedFrameIndex = i
						-- Center body timeline on this frame timestamp
						local UIBody = require("Profiler.ui_body")
						if UIBody and UIBody.CenterOnTimestamp then
							UIBody.CenterOnTimestamp(frame.timestamp)
						end
						break
					end
				end
			end
		end
	end
end

-- Handle key capture and shortcuts
local function handleKeys()
	if not input then
		return
	end

	-- Key capture mode
	if isCapturingKey and input.IsButtonPressed then
		for keyId = 0, 113 do
			if input.IsButtonPressed(keyId) and keyId ~= MOUSE_LEFT then
				bodyKey = keyId
				isCapturingKey = false
				break
			end
		end
	end

	-- Pause shortcut
	if consumeKeyPress(KEY_P) then
		isPaused = not isPaused
		-- Sync pause state with microprofiler
		local MicroProfiler = require("Profiler.microprofiler")
		MicroProfiler.SetPaused(isPaused)
	end

	-- Body visibility shortcut
	if bodyKey and consumeKeyPress(bodyKey) then
		-- This will be handled by the main profiler
		Shared.BodyToggleRequested = true
	end
end

-- Public API -------------------------

function UITop.Initialize()
	initializeFont()
	isPaused = false
	isCapturingKey = false
	bodyKey = 25 -- Default to 'O' key
	selectedFrameIndex = nil
	frames = {}
	totalRecordedTime = 0
end

function UITop.Update()
	updateFrameRecording()
end

function UITop.Draw()
	if not draw then
		return
	end

	local screenW, _ = draw.GetScreenSize()

	-- Set font
	if topBarFont and draw.SetFont then
		draw.SetFont(topBarFont)
	end

	-- Draw background
	draw.Color(18, 18, 18, 200)
	safeFilledRect(0, 0, screenW, TIMELINE_HEIGHT)
	draw.Color(70, 70, 70, 255)
	draw.OutlinedRect(0, 0, screenW, TIMELINE_HEIGHT)

	-- Draw left side info (integer coordinates for crisp text, larger font spacing)
	assert(globals and globals.TickInterval, "UITop.Draw: globals.TickInterval missing")
	local dt = globals.TickInterval()
	local fps = dt > 0 and math.floor(1 / dt + 0.5) or 0
	draw.Color(230, 230, 230, 255)
	draw.Text(8, 6, "FPS: " .. tostring(fps))

	-- Draw profiler status
	local status = isPaused and "PAUSED" or "RECORDING"
	if isPaused then
		draw.Color(255, 200, 0, 255)
	else
		draw.Color(0, 255, 0, 255)
	end
	draw.Text(8, 26, status)

	-- Draw frame count info
	draw.Color(180, 180, 180, 255)
	draw.Text(8, 46, "Frames: " .. tostring(#frames))

	-- Draw frame pillars
	drawFramePillars(screenW)

	-- Draw controls
	local buttonX, pauseY, bindY = drawControls(screenW)

	-- Handle input
	handleInput(screenW, buttonX, pauseY, bindY)
	handleKeys()

	-- Draw selected frame cursor
	if selectedFrameIndex and frames[selectedFrameIndex] and frames[selectedFrameIndex]._clickRegion then
		local region = frames[selectedFrameIndex]._clickRegion
		local cursorX = region.x + region.w / 2
		draw.Color(0, 255, 0, 255)
		safeFilledRect(cursorX - 1, 0, cursorX + 1, TIMELINE_HEIGHT)
	end
end

function UITop.SetPaused(paused)
	isPaused = paused
	-- Also set pause state in microprofiler
	local MicroProfiler = require("Profiler.microprofiler")
	MicroProfiler.SetPaused(paused)
end

function UITop.IsPaused()
	return isPaused
end

function UITop.GetSelectedFrame()
	if selectedFrameIndex and frames[selectedFrameIndex] then
		return frames[selectedFrameIndex]
	end
	return nil
end

function UITop.GetFrames()
	return frames
end

function UITop.SetBodyKey(keyId)
	bodyKey = keyId
end

function UITop.GetBodyKey()
	return bodyKey
end

return UITop
