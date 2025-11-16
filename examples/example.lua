--[[
    PROFILER EXAMPLE - Super Simple Usage
    
    HOW TO USE:
    1. Load this script
    2. Profiler draws automatically
    3. Use Profiler.Begin("Name") and Profiler.End() to measure code
    4. Set mode: Profiler.SetMeasurementMode("tick") or ("frame")
    
    BASIC PATTERN:
        Profiler.Begin("MyWork")
        -- your code here
        Profiler.End()
]]

local SCRIPT_TAG = "profiler_example"

-- Load profiler
local Profiler = require("Profiler")
Profiler.SetVisible(true)
Profiler.SetMeasurementMode("frame") -- or "tick"

-- Helper: Do some work
local function doPathfinding()
	Profiler.Begin("AI.Pathfinding")
	local sum = 0
	for i = 1, 50 do
		sum = sum + math.sin(i * 0.1)
	end
	Profiler.End()
end

local function doRendering()
	Profiler.Begin("Render.DrawStuff")
	local t = globals.RealTime()
	for i = 1, 30 do
		local _ = math.cos(t + i * 0.1)
	end
	Profiler.End()
end

local function doPhysics()
	Profiler.Begin("Physics.Step")
	for i = 1, 20 do
		local _ = math.sqrt(i)
	end
	Profiler.End()
end

-- CreateMove callback - runs every tick
local function onCreateMove(cmd)
	Profiler.SetMeasurementMode("tick") -- Tick mode for CreateMove

	Profiler.Begin("GameTick")
	doPathfinding()
	doPhysics()
	Profiler.End()
end

-- Draw callback - runs every frame
local function onDraw()
	Profiler.SetMeasurementMode("frame") -- Frame mode for Draw

	Profiler.Begin("Frame")
	doRendering()
	Profiler.Draw() -- Draws the profiler UI
	Profiler.End()
end

-- Unload callback
local function onUnload()
	print("[Profiler Example] unloaded")
	Profiler.SetVisible(false)
end

-- Register callbacks (no anonymous functions!)
callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, onUnload)

print("[Profiler Example] loaded. Measuring ticks in CreateMove, frames in Draw.")
