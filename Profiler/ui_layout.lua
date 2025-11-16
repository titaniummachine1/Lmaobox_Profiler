--[[
    UI Layout Module - Dual-Zone Profiler Layout (Tick + Frame)
    Implements Roblox-style MicroProfiler layout with hierarchical stacking
]]

local Shared = require("Profiler.Shared")

local UILayout = {}

-- Constants
local RULER_HEIGHT = 30
local ZONE_HEADER_HEIGHT = 20
local PROCESS_HEADER_HEIGHT = 18
local WORK_HEIGHT = 16
local WORK_SPACING = 2
local TIME_SCALE = 50000 -- px/s (1ms = 50px)

-- Layout work items with horizontal packing (Roblox style)
-- Items share lanes when they don't overlap in time
local function layoutHorizontalPacking(workItems, startY)
	local layout = {}
	local stackLevels = {} -- Track occupied time ranges at each Y level

	-- Flatten all work items (including children)
	local allWork = {}
	local function flatten(work)
		table.insert(allWork, work)
		if work.children and #work.children > 0 then
			for _, child in ipairs(work.children) do
				flatten(child)
			end
		end
	end

	for _, work in ipairs(workItems) do
		flatten(work)
	end

	-- Find available Y level for each work item based on time overlap
	for _, work in ipairs(allWork) do
		if work.startTime and work.endTime then
			local level = 0
			local foundLevel = false

			-- Find first available level where this work doesn't overlap
			while not foundLevel do
				local conflictFound = false

				if stackLevels[level] then
					for _, occupiedRange in ipairs(stackLevels[level]) do
						-- Check if time ranges overlap
						if not (work.endTime <= occupiedRange.startTime or work.startTime >= occupiedRange.endTime) then
							conflictFound = true
							break
						end
					end
				end

				if not conflictFound then
					-- This level is available
					if not stackLevels[level] then
						stackLevels[level] = {}
					end
					table.insert(stackLevels[level], { startTime = work.startTime, endTime = work.endTime })
					foundLevel = true
				else
					level = level + 1
				end
			end

			-- Add to layout
			table.insert(layout, {
				work = work,
				y = startY + (level * (WORK_HEIGHT + WORK_SPACING)),
				height = WORK_HEIGHT,
				depth = 0, -- No indentation in horizontal packing
			})
		end
	end

	-- Calculate total height
	local maxLevel = 0
	for level, _ in pairs(stackLevels) do
		maxLevel = math.max(maxLevel, level)
	end
	local endY = startY + ((maxLevel + 1) * (WORK_HEIGHT + WORK_SPACING))

	return layout, endY
end

-- Group work by measurement mode (tick vs frame)
function UILayout.GroupByMode(profilerData)
	local tickWork = {}
	local frameWork = {}

	if profilerData.scriptTimelines then
		for processName, processData in pairs(profilerData.scriptTimelines) do
			if processData.functions and #processData.functions > 0 then
				for _, work in ipairs(processData.functions) do
					local mode = work.measurementMode or "frame"
					if mode == "tick" then
						table.insert(tickWork, work)
					else
						table.insert(frameWork, work)
					end
				end
			end
		end
	end

	return tickWork, frameWork
end

-- Create layout for entire profiler (tick zone + frame zone)
function UILayout.CreateLayout(profilerData, topBarHeight, screenH)
	local layout = {
		tickZone = nil,
		frameZone = nil,
		totalHeight = 0,
	}

	local tickWork, frameWork = UILayout.GroupByMode(profilerData)

	local currentY = topBarHeight

	-- TICK ZONE
	if #tickWork > 0 then
		local zoneY = currentY
		currentY = currentY + ZONE_HEADER_HEIGHT + RULER_HEIGHT

		local workLayout, endY = layoutHorizontalPacking(tickWork, currentY)

		layout.tickZone = {
			startY = zoneY,
			rulerY = zoneY + ZONE_HEADER_HEIGHT,
			workY = currentY,
			endY = endY,
			height = endY - zoneY,
			work = workLayout,
			mode = "tick",
		}

		currentY = endY + 20 -- Spacing between zones
	end

	-- FRAME ZONE
	if #frameWork > 0 then
		local zoneY = currentY
		currentY = currentY + ZONE_HEADER_HEIGHT + RULER_HEIGHT

		local workLayout, endY = layoutHorizontalPacking(frameWork, currentY)

		layout.frameZone = {
			startY = zoneY,
			rulerY = zoneY + ZONE_HEADER_HEIGHT,
			workY = currentY,
			endY = endY,
			height = endY - zoneY,
			work = workLayout,
			mode = "frame",
		}

		currentY = endY
	end

	layout.totalHeight = currentY - topBarHeight

	return layout
end

return UILayout
