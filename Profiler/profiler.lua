--[[
    Simple Performance Profiler Library for Lmaobox
    Author: titaniummachine1
    
    Usage:
    local Profiler = require("profiler")
    
    -- Control visibility
    Profiler.SetVisible(true)
    
    -- Measure systems with arbitrary tags
    Profiler.StartSystem("ontick")
        Profiler.StartComponent("UpdateTargets")
        -- ... your code ...
        Profiler.EndComponent("UpdateTargets")
        
        Profiler.StartComponent("SimulateMovement")
        -- ... your code ...
        Profiler.EndComponent("SimulateMovement")
    Profiler.EndSystem("ontick")
    
    -- In draw callback
    Profiler.Draw()
]]

local Profiler = {}

-- Configuration (can be modified at runtime or loaded from file)
local Config = {
	visible = false,
	windowSize = 60, -- frames to average over
	sortMode = "size", -- "size" (biggest to smallest), "static" (measurement order), "reverse" (smallest to biggest)
	systemHeight = 48, -- height of each system bar (enough for name + memory + time)
	fontSize = 12,
	maxSystems = 20, -- max systems before we stop drawing more
	textPadding = 6, -- padding around text in components
	smoothingSpeed = 8.0, -- How fast bars scale up to peaks (higher = faster response to spikes)
	smoothingDecay = 2.0, -- How fast bars scale down from peaks (lower = slower decay)
}

-- Active measurements
local Systems = {} -- [systemName] = { components = {}, totalTime = 0, totalMemory = 0, lastActive = frameNum, order = num }
local SystemOrder = {} -- Track order systems were first measured
local SystemStack = {} -- Stack for nested system calls
local ComponentStack = {} -- Stack for nested component calls within current system

-- Rolling history for smooth averaging
local History = {} -- [systemName][componentName] = circular buffer
local HistoryIndex = 1
local HistoryCount = 0

-- Display state for smooth transitions
local DisplayState = {} -- [systemName][componentName] = { width = current_width, targetWidth = target_width }

-- Current frame tracking
local CurrentSystem = nil
local CurrentFrame = 0

-- Font (create once)
local ProfilerFont = nil

-- Helper function to validate numeric values
local function ValidateNumber(value, fallback)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback or 0
	end
	return value
end

-- Smooth interpolation using frame time with peak-aware behavior
local function SmoothLerp(current, target, speed, decaySpeed)
	local frameTime = globals.FrameTime()

	-- Use faster speed for increases (catching spikes), slower for decreases (showing peaks longer)
	local actualSpeed = target > current and speed or (decaySpeed or speed * 0.5)
	local lerpFactor = math.min(1.0, actualSpeed * frameTime)

	return current + (target - current) * lerpFactor
end

-- Initialize profiler font
local function InitializeFont()
	if not ProfilerFont then
		ProfilerFont = draw.CreateFont("Arial", Config.fontSize, 400)
	end
end

-- Load configuration from file (optional)
local function LoadConfig()
	local success, configFile = pcall(require, "Profiler.config")
	if success and type(configFile) == "table" then
		for key, value in pairs(configFile) do
			if Config[key] ~= nil then
				Config[key] = value
			end
		end
	end
end

-- Get current frame number using globals API
local function GetFrameNumber()
	if globals and globals.FrameCount then
		return globals.FrameCount()
	else
		-- Fallback if globals.FrameCount() doesn't exist
		CurrentFrame = CurrentFrame + 1
		return CurrentFrame
	end
end

-- Initialize system if it doesn't exist
local function InitializeSystem(systemName)
	if not Systems[systemName] then
		Systems[systemName] = {
			components = {},
			totalTime = 0,
			totalMemory = 0,
			lastActive = 0,
			order = #SystemOrder + 1,
		}
		table.insert(SystemOrder, systemName)

		-- Initialize history
		History[systemName] = {}

		-- Initialize display state
		DisplayState[systemName] = {}
	end
end

-- Initialize component display state
local function InitializeComponentDisplay(systemName, componentName)
	if not DisplayState[systemName] then
		DisplayState[systemName] = {}
	end

	if not DisplayState[systemName][componentName] then
		DisplayState[systemName][componentName] = {
			width = 0,
			targetWidth = 0,
		}
	end
end

-- Public API
function Profiler.SetVisible(visible)
	Config.visible = visible
	if visible then
		InitializeFont()
	end
end

function Profiler.StartSystem(systemName)
	if not Config.visible then
		return
	end

	InitializeSystem(systemName)

	-- Use high-precision timing for real-time profiling
	local currentTime = globals.RealTime()
	local currentMemory = collectgarbage("count")

	table.insert(SystemStack, {
		name = systemName,
		startTime = currentTime,
		startMemory = currentMemory,
		-- Cache baseline for better accuracy
		baselineTime = currentTime,
		baselineMemory = currentMemory,
	})

	CurrentSystem = systemName
	Systems[systemName].lastActive = GetFrameNumber()

	-- Reset components for this frame
	for componentName, component in pairs(Systems[systemName].components) do
		component.frameTime = 0
		component.frameMemory = 0
	end
end

function Profiler.StartComponent(componentName)
	if not Config.visible then
		return
	end

	-- If no current system, automatically start a default "misc" system
	if not CurrentSystem then
		Profiler.StartSystem("misc")
	end

	-- Minimize measurement overhead for real-time profiling
	local startTime = globals.RealTime()
	local startMemory = nil

	-- Only measure memory every few calls to reduce overhead
	-- This gives representative samples without constant GC calls
	local shouldMeasureMemory = (GetFrameNumber() % 5) == 0
	if shouldMeasureMemory then
		startMemory = collectgarbage("count")
	end

	table.insert(ComponentStack, {
		name = componentName,
		startTime = startTime,
		startMemory = startMemory,
		measureMemory = shouldMeasureMemory,
	})
end

function Profiler.EndComponent(componentName)
	if not Config.visible or not CurrentSystem or #ComponentStack == 0 then
		return
	end

	local component = table.remove(ComponentStack)
	if component.name ~= componentName then
		-- Mismatched component calls - clear stack and return
		ComponentStack = {}
		return
	end

	-- High-precision timing measurement
	local endTime = globals.RealTime()
	local duration = ValidateNumber(endTime - component.startTime, 0)

	-- Smart memory measurement to reduce overhead
	local memoryDelta = 0
	if component.measureMemory and component.startMemory then
		local endMemory = collectgarbage("count")
		-- Only count positive memory growth (actual allocations)
		-- Negative values usually mean GC ran, which isn't our function's fault
		local rawDelta = endMemory - component.startMemory
		if rawDelta > 0.01 then -- Only count meaningful memory increases (>0.01KB)
			memoryDelta = ValidateNumber(rawDelta, 0)
		end
	end

	local system = Systems[CurrentSystem]
	if not system.components[componentName] then
		system.components[componentName] = {
			avgTime = 0,
			avgMemory = 0,
			frameTime = 0,
			frameMemory = 0,
			order = 0,
		}

		-- Set order based on when first measured
		local componentCount = 0
		for _ in pairs(system.components) do
			componentCount = componentCount + 1
		end
		system.components[componentName].order = componentCount

		-- Initialize component history
		History[CurrentSystem][componentName] = {}
		for i = 1, Config.windowSize do
			History[CurrentSystem][componentName][i] = { time = 0, memory = 0 }
		end

		-- Initialize display state
		InitializeComponentDisplay(CurrentSystem, componentName)
	end

	system.components[componentName].frameTime = system.components[componentName].frameTime + duration
	system.components[componentName].frameMemory = system.components[componentName].frameMemory + memoryDelta
end

function Profiler.EndSystem(systemName)
	if not Config.visible or #SystemStack == 0 then
		return
	end

	local systemData = table.remove(SystemStack)
	if systemData.name ~= systemName then
		-- Mismatched system calls - clear stacks and return
		SystemStack = {}
		ComponentStack = {}
		return
	end

	local system = Systems[systemName]
	if system then
		system.totalTime = ValidateNumber(globals.RealTime() - systemData.startTime, 0)
		system.totalMemory = ValidateNumber(math.abs(collectgarbage("count") - systemData.startMemory), 0)

		-- Update rolling averages for all components
		for componentName, component in pairs(system.components) do
			if not History[systemName][componentName] then
				History[systemName][componentName] = {}
				for i = 1, Config.windowSize do
					History[systemName][componentName][i] = { time = 0, memory = 0 }
				end
			end

			-- Store current frame data into circular history buffer
			History[systemName][componentName][HistoryIndex] = {
				time = component.frameTime,
				memory = component.frameMemory,
			}

			-- Compute rolling average over the last windowSize frames (~1 second)
			local totalTime, totalMemory = 0, 0
			local frames = math.min(HistoryCount, Config.windowSize)
			for i = 1, frames do
				local h = History[systemName][componentName][i]
				totalTime = totalTime + ValidateNumber(h.time, 0)
				totalMemory = totalMemory + ValidateNumber(h.memory, 0)
			end
			component.avgTime = ValidateNumber(frames > 0 and totalTime / frames or 0, 0)
			component.avgMemory = ValidateNumber(frames > 0 and totalMemory / frames or 0, 0)
		end
	end

	CurrentSystem = #SystemStack > 0 and SystemStack[#SystemStack].name or nil

	-- Advance circular history index once per frame when we end the outermost system
	if CurrentSystem == nil then
		HistoryIndex = HistoryIndex + 1
		if HistoryIndex > Config.windowSize then
			HistoryIndex = 1
		end
		if HistoryCount < Config.windowSize then
			HistoryCount = HistoryCount + 1
		end
	end
end

-- Get sorted components based on sort mode
local function GetSortedComponents(system)
	local components = {}

	for name, data in pairs(system.components) do
		table.insert(components, { name = name, data = data })
	end

	if Config.sortMode == "size" then
		table.sort(components, function(a, b)
			return a.data.avgTime > b.data.avgTime
		end)
	elseif Config.sortMode == "reverse" then
		table.sort(components, function(a, b)
			return a.data.avgTime < b.data.avgTime
		end)
	elseif Config.sortMode == "static" then
		table.sort(components, function(a, b)
			return a.data.order < b.data.order
		end)
	end

	return components
end

-- Draw the profiler
function Profiler.Draw()
	if not Config.visible then
		return
	end

	InitializeFont()
	draw.SetFont(ProfilerFont)

	local screenW, screenH = draw.GetScreenSize()
	local currentFrame = GetFrameNumber()

	-- Filter active systems (only show systems used recently)
	local activeSystems = {}
	for _, systemName in ipairs(SystemOrder) do
		local system = Systems[systemName]
		if system and (currentFrame - system.lastActive) < Config.windowSize then
			table.insert(activeSystems, systemName)
		end
	end

	-- Limit number of systems displayed
	local systemsToShow = math.min(#activeSystems, Config.maxSystems)
	local totalHeight = systemsToShow * Config.systemHeight
	local startY = screenH - totalHeight

	-- Draw each system
	for i = 1, systemsToShow do
		local systemName = activeSystems[i]
		local system = Systems[systemName]
		local systemY = startY + (i - 1) * Config.systemHeight

		-- Get sorted components
		local sortedComponents = GetSortedComponents(system)

		-- Calculate total memory for scaling (focus on memory, not time)
		local totalSystemMemory = math.max(system.totalMemory, 0.001) -- Prevent division by zero

		-- Draw system background (spans full width)
		draw.Color(20, 20, 20, 180)
		draw.FilledRect(0, math.floor(systemY), screenW, math.floor(systemY + Config.systemHeight))

		-- Draw system border
		draw.Color(80, 80, 80, 255)
		draw.OutlinedRect(0, math.floor(systemY), screenW, math.floor(systemY + Config.systemHeight))

		-- Draw system totals at the beginning (left side)
		local systemLabelWidth = 200 -- Reserve space for system label
		draw.Color(255, 255, 255, 255)
		local systemText = systemName
		local memoryText = string.format("%.1fKB", system.totalMemory)

		-- Draw system name (fixed position for stable text)
		draw.Text(5, math.floor(systemY + 2), systemText)

		-- Draw system memory total below name (fixed position for stable text)
		draw.Color(200, 200, 200, 255)
		draw.Text(5, math.floor(systemY + 16), memoryText)

		-- Draw components (starting after system label area)
		local componentStartX = systemLabelWidth
		local componentAreaWidth = screenW - systemLabelWidth
		local currentX = componentStartX

		for _, comp in ipairs(sortedComponents) do
			local componentName = comp.name
			local componentData = comp.data

			-- Initialize display state if needed
			InitializeComponentDisplay(systemName, componentName)
			local displayState = DisplayState[systemName][componentName]

			-- Calculate dynamic minimum width based on text content
			local timeMs = componentData.avgTime * 1000
			local memKB = componentData.avgMemory
			local hasTime = timeMs >= 0.01

			-- Measure text widths for stable minimum sizing
			local nameWidth = draw.GetTextSize(componentName)
			local memText = string.format("%.1fKB", memKB)
			local memWidth = draw.GetTextSize(memText)

			local timeWidth = 0
			if hasTime then
				local timeText = string.format("%.2fms", timeMs)
				timeWidth = draw.GetTextSize(timeText)
			end

			-- Use the widest text as minimum width (plus padding)
			local minComponentWidth = math.max(nameWidth, memWidth, timeWidth) + Config.textPadding

			-- Calculate target component width proportional to memory usage
			local targetWidth = minComponentWidth
			if totalSystemMemory > 0 and componentData.avgMemory > 0 then
				local memoryProportion = componentData.avgMemory / totalSystemMemory
				local proportionalWidth = componentAreaWidth * memoryProportion
				targetWidth = math.max(minComponentWidth, proportionalWidth)
			end

			-- Ensure we don't exceed available component area
			local remainingWidth = screenW - currentX
			targetWidth = math.min(targetWidth, remainingWidth)

			-- Update display state with smooth interpolation
			displayState.targetWidth = targetWidth
			displayState.width =
				SmoothLerp(displayState.width, displayState.targetWidth, Config.smoothingSpeed, Config.smoothingDecay)

			-- Use the smoothed width for rendering
			local componentWidth = displayState.width

			if componentWidth > 10 and currentX < screenW - 10 then -- Only draw if meaningful size
				-- Generate color based on component name hash
				local hash = 0
				for j = 1, #componentName do
					hash = hash + string.byte(componentName, j)
				end
				local r = (hash * 73) % 255
				local g = (hash * 151) % 255
				local b = (hash * 211) % 255

				-- Draw component background (inset within system bar to show hierarchy)
				local insetY = systemY + 2
				local insetHeight = Config.systemHeight - 4

				draw.Color(r, g, b, 200)
				draw.FilledRect(
					math.floor(currentX),
					math.floor(insetY),
					math.floor(currentX + componentWidth),
					math.floor(insetY + insetHeight)
				)

				-- Draw component border
				draw.Color(255, 255, 255, 150)
				draw.OutlinedRect(
					math.floor(currentX),
					math.floor(insetY),
					math.floor(currentX + componentWidth),
					math.floor(insetY + insetHeight)
				)

				-- Draw component text with stable positioning
				local textX = currentX + 3
				local textY = insetY + 2

				draw.Color(255, 255, 255, 255)

				-- Component name (shortened if needed, but stable)
				local nameText = componentName
				local nameWidth, nameHeight = draw.GetTextSize(nameText)

				-- Shorten name if too long for current width
				if nameWidth + 6 > componentWidth and #nameText > 3 then
					nameText = string.sub(nameText, 1, math.max(1, math.floor(componentWidth / 8))) .. "..."
					nameWidth, nameHeight = draw.GetTextSize(nameText)
				end

				if nameWidth + 6 <= componentWidth then
					draw.Text(math.floor(textX), math.floor(textY), nameText)
				end

				-- Memory amount (always visible, fixed position)
				local infoY = textY + nameHeight + 3
				draw.Color(220, 220, 220, 255)
				draw.Text(math.floor(textX), math.floor(infoY), memText)

				-- Time display with red background if measurable
				if hasTime then
					local timeText = string.format("%.2fms", timeMs)
					local timeWidth, timeHeight = draw.GetTextSize(timeText)
					local timeY = infoY + 14 -- Fixed position below memory

					-- Check if there's space for time display
					if timeY + timeHeight <= insetY + insetHeight - 2 and timeWidth + 6 <= componentWidth then
						-- Draw red background for time highlighting
						draw.Color(150, 50, 50, 180)
						draw.FilledRect(
							math.floor(textX - 1),
							math.floor(timeY - 1),
							math.floor(textX + timeWidth + 2),
							math.floor(timeY + timeHeight + 1)
						)

						-- Draw time text
						draw.Color(255, 255, 255, 255)
						draw.Text(math.floor(textX), math.floor(timeY), timeText)
					end
				end

				-- Use the smoothed width for positioning next component
				currentX = currentX + componentWidth
			end
		end
	end
end

-- Configuration functions
function Profiler.SetSortMode(mode)
	if mode == "size" or mode == "static" or mode == "reverse" then
		Config.sortMode = mode
	end
end

function Profiler.SetWindowSize(frames)
	Config.windowSize = math.max(1, math.min(frames, 300))
end

function Profiler.SetSmoothingSpeed(speed)
	Config.smoothingSpeed = math.max(0.1, math.min(speed, 20.0))
end

function Profiler.SetSmoothingDecay(decay)
	Config.smoothingDecay = math.max(0.1, math.min(decay, 20.0))
end

function Profiler.Reset()
	Systems = {}
	SystemOrder = {}
	History = {}
	DisplayState = {}
	SystemStack = {}
	ComponentStack = {}
	CurrentSystem = nil
	HistoryIndex = 1
	HistoryCount = 0
end

-- Load configuration on startup
LoadConfig()

return Profiler
