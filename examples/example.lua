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

-- Heavy pathfinding with sub-tasks
local function calculatePath()
	Profiler.Begin("AI.PathCalculation")
	local sum = 0
	for i = 1, 5000 do
		sum = sum + math.sin(i * 0.1)
	end
	Profiler.End()
end

local function optimizePath()
	Profiler.Begin("AI.PathOptimization")
	for i = 1, 3000 do
		local _ = math.log(i + 1)
	end
	Profiler.End()
end

local function validatePath()
	Profiler.Begin("AI.PathValidation")
	for i = 1, 4000 do
		local _ = math.sqrt(i)
	end
	Profiler.End()
end

local function doPathfinding()
	Profiler.Begin("AI.Pathfinding") -- Parent task

	-- Child tasks (heavyweight pathfinding)
	calculatePath()
	optimizePath()
	validatePath()

	Profiler.End()
end

-- Heavy rendering with sub-tasks
local function renderGeometry()
	Profiler.Begin("Render.Geometry")
	local t = globals.RealTime()
	for i = 1, 8000 do
		local _ = math.cos(t + i * 0.1)
	end
	Profiler.End()
end

local function renderShadows()
	Profiler.Begin("Render.Shadows")
	for i = 1, 4000 do
		local _ = math.tan(i * 0.05)
	end
	Profiler.End()
end

local function renderLighting()
	Profiler.Begin("Render.Lighting")
	for i = 1, 6000 do
		local _ = math.exp(i * 0.001)
	end
	Profiler.End()
end

local function renderPostProcess()
	Profiler.Begin("Render.PostProcess")
	for i = 1, 3000 do
		local _ = math.sin(i * 0.08) * math.cos(i * 0.04)
	end
	Profiler.End()
end

local function doRendering()
	Profiler.Begin("Render.Frame") -- Parent task

	-- Child tasks (heavy rendering pipeline)
	renderGeometry()
	renderShadows()
	renderLighting()
	renderPostProcess()

	Profiler.End()
end

-- Heavy physics with sub-tasks
local function broadPhase()
	Profiler.Begin("Physics.BroadPhase")
	for i = 1, 2000 do
		local _ = math.abs(i - 1000)
	end
	Profiler.End()
end

local function narrowPhase()
	Profiler.Begin("Physics.NarrowPhase")
	for i = 1, 3000 do
		local _ = math.sqrt(i) * math.log(i + 1)
	end
	Profiler.End()
end

local function integration()
	Profiler.Begin("Physics.Integration")
	for i = 1, 5000 do
		local _ = math.sin(i * 0.05)
	end
	Profiler.End()
end

local function constraintSolver()
	Profiler.Begin("Physics.Constraints")
	for i = 1, 4000 do
		local _ = math.cos(i * 0.03)
	end
	Profiler.End()
end

local function doPhysics()
	Profiler.Begin("Physics.Step") -- Parent task

	-- Child tasks (heavy physics simulation)
	broadPhase()
	narrowPhase()
	integration()
	constraintSolver()

	Profiler.End()
end

-- Heavy networking with sub-tasks
local function receivePackets()
	Profiler.Begin("Net.Receive")
	for i = 1, 2000 do
		local _ = string.format("packet_%d", i)
	end
	Profiler.End()
end

local function processPackets()
	Profiler.Begin("Net.Process")
	for i = 1, 3000 do
		local _ = math.floor(i / 16) * 16
	end
	Profiler.End()
end

local function sendPackets()
	Profiler.Begin("Net.Send")
	for i = 1, 1500 do
		local _ = string.format("out_%d", i)
	end
	Profiler.End()
end

local function doNetworking()
	Profiler.Begin("Net.PacketProcess") -- Parent task

	-- Child tasks (network pipeline)
	receivePackets()
	processPackets()
	sendPackets()

	Profiler.End()
end

-- CreateMove callback - runs every tick (shows tick-based ruler with T0, T1, T2...)
local function onCreateMove(cmd)
	Profiler.SetMeasurementMode("tick") -- Tick mode for CreateMove

	Profiler.Begin("TickProcess") -- Top-level tick work

	-- Compound tasks with heavy nested work
	doPathfinding() -- Contains PathCalculation + Optimization + Validation
	doPhysics() -- Contains BroadPhase + NarrowPhase + Integration + Constraints
	doNetworking() -- Contains Receive + Process + Send

	Profiler.End()
end

-- Draw callback - runs every frame (shows frame-based ruler with F0, F1, F2...)
local function onDraw()
	Profiler.SetMeasurementMode("frame") -- Frame mode for Draw

	Profiler.Begin("FrameProcess") -- Top-level frame work

	-- Compound rendering with heavy nested work
	doRendering() -- Contains Geometry + Shadows + Lighting + PostProcess
	doPhysics() -- Also do some physics in frame for comparison

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
