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

-- Helper: Nested work showing compound tasks

local function calculatePath()
	Profiler.Begin("AI.PathCalculation")
	local sum = 0
	for i = 1, 2000 do
		sum = sum + math.sin(i * 0.1)
	end
	Profiler.End()
end

local function validatePath()
	Profiler.Begin("AI.PathValidation")
	for i = 1, 1500 do
		local _ = math.sqrt(i)
	end
	Profiler.End()
end

local function doPathfinding()
	Profiler.Begin("AI.Pathfinding") -- Parent task

	-- Child tasks
	calculatePath()
	validatePath()

	Profiler.End()
end

local function renderGeometry()
	Profiler.Begin("Render.Geometry")
	local t = globals.RealTime()
	for i = 1, 2000 do
		local _ = math.cos(t + i * 0.1)
	end
	Profiler.End()
end

local function renderLighting()
	Profiler.Begin("Render.Lighting")
	for i = 1, 1000 do
		local _ = math.exp(i * 0.001)
	end
	Profiler.End()
end

local function doRendering()
	Profiler.Begin("Render.Frame") -- Parent task

	-- Child tasks
	renderGeometry()
	renderLighting()

	Profiler.End()
end

local function collisionDetection()
	Profiler.Begin("Physics.Collision")
	for i = 1, 1500 do
		local _ = math.sqrt(i) * math.log(i + 1)
	end
	Profiler.End()
end

local function integration()
	Profiler.Begin("Physics.Integration")
	for i = 1, 2000 do
		local _ = math.sin(i * 0.05)
	end
	Profiler.End()
end

local function doPhysics()
	Profiler.Begin("Physics.Step") -- Parent task

	-- Child tasks
	collisionDetection()
	integration()

	Profiler.End()
end

local function doNetworking()
	Profiler.Begin("Net.PacketProcess")
	for i = 1, 1000 do
		local _ = string.format("packet_%d", i)
	end
	Profiler.End()
end

-- CreateMove callback - runs every tick (shows tick-based ruler)
local function onCreateMove(cmd)
	Profiler.SetMeasurementMode("tick") -- Tick mode for CreateMove

	Profiler.Begin("GameTick") -- Top-level work

	-- Compound tasks with nested work
	doPathfinding() -- Contains PathCalculation + PathValidation
	doPhysics() -- Contains Collision + Integration
	doNetworking()

	Profiler.End()
end

-- Draw callback - runs every frame (shows frame-based ruler)
local function onDraw()
	Profiler.SetMeasurementMode("frame") -- Frame mode for Draw

	Profiler.Begin("RenderFrame") -- Top-level work

	-- Compound rendering with nested work
	doRendering() -- Contains Geometry + Lighting

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
