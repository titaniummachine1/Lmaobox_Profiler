--[[
    PROFILER EXAMPLE - Super Simple Usage
    
    HOW TO USE:
    1. Load this script
    2. Profiler draws automatically
    3. Use Profiler.SetContext("tick") in CreateMove, SetContext("frame") in Draw
    4. Use Profiler.Begin("Name") and Profiler.End() to measure code
    
    BASIC PATTERN:
        Profiler.Begin("MyWork")
        -- your code here
        Profiler.End()
]]

local SCRIPT_TAG = "profiler_example"

-- Properly unload existing profiler instance before loading new one
if _G.PROFILER_EXAMPLE_LOADED then
	print("[Profiler Example] Unloading previous profiler instance...")
	callbacks.Unregister("CreateMove", SCRIPT_TAG)
	callbacks.Unregister("Draw", SCRIPT_TAG)
	callbacks.Unregister("Unload", SCRIPT_TAG)
	_G.PROFILER_EXAMPLE_LOADED = false
end

-- Load profiler
local Profiler = require("Profiler")

Profiler.SetVisible(true)

_G.PROFILER_EXAMPLE_LOADED = true

-- Helper: Nested work showing compound tasks

-- Heavy pathfinding with sub-tasks (automatic nesting)
local function calculatePath()
	Profiler.Begin("PathCalculation")
	local pathNodes = {}
	for i = 1, 800 do
		pathNodes[i] = {
			x = math.sin(i * 0.1) * 100,
			y = math.cos(i * 0.1) * 100,
			z = math.tan(i * 0.05) * 50,
			cost = i * 0.5,
		}
	end
	Profiler.End("PathCalculation")
end

local function optimizePath()
	Profiler.Begin("PathOptimization")
	local optimizedNodes = {}
	for i = 1, 200 do
		optimizedNodes[i] = string.format("node_%d_%.2f", i, math.log(i + 1))
	end
	Profiler.End("PathOptimization")
end

local function validatePath()
	Profiler.Begin("PathValidation")
	local validationData = {}
	for i = 1, 150 do
		validationData[i] = {
			valid = math.sqrt(i) > 10,
			score = math.random() * 100,
			metadata = string.format("check_%d", i),
		}
	end
	Profiler.End("PathValidation")
end

local function doPathfinding()
	Profiler.Begin("Pathfinding") -- Parent task

	-- Child tasks automatically become nested under Pathfinding
	calculatePath()
	optimizePath()
	validatePath()

	Profiler.End("Pathfinding")
end

-- Heavy rendering with sub-tasks
local function renderGeometry()
	Profiler.Begin("Geometry")
	local vertices = {}
	local t = globals.RealTime()
	for i = 1, 1500 do
		vertices[i] = {
			pos = { math.cos(t + i * 0.1), math.sin(t + i * 0.1), i * 0.01 },
			normal = { 0, 1, 0 },
			uv = { i % 10, i % 20 },
		}
	end
	Profiler.End("Geometry")
end

local function renderShadows()
	Profiler.Begin("Shadows")
	local shadowMaps = {}
	for i = 1, 300 do
		shadowMaps[i] = {
			depth = math.tan(i * 0.05),
			intensity = math.random(),
			coords = string.format("%d,%d", i % 100, math.floor(i / 100)),
		}
	end
	Profiler.End("Shadows")
end

local function renderLighting()
	Profiler.Begin("Lighting")
	local lights = {}
	for i = 1, 500 do
		lights[i] = {
			color = { math.random() * 255, math.random() * 255, math.random() * 255 },
			intensity = math.exp(i * 0.001),
			position = { i % 50, i % 30, math.floor(i / 100) },
			type = i % 3 == 0 and "point" or "spot",
		}
	end
	Profiler.End("Lighting")
end

local function renderPostProcess()
	Profiler.Begin("PostProcess")
	for i = 1, 303 do
		local _ = math.sin(i * 0.08) * math.cos(i * 0.04)
	end
	Profiler.End("PostProcess")
end

local function doRendering()
	Profiler.Begin("RenderFrame") -- Parent task

	-- Child tasks automatically become nested under RenderFrame
	renderGeometry()
	renderShadows()
	renderLighting()
	renderPostProcess()

	Profiler.End("RenderFrame")
end

-- Heavy physics with sub-tasks
local function broadPhase()
	Profiler.Begin("BroadPhase")
	for i = 1, 203 do
		local _ = math.abs(i - 1000)
	end
	Profiler.End("BroadPhase")
end

local function narrowPhase()
	Profiler.Begin("NarrowPhase")
	for i = 1, 332 do
		local _ = math.sqrt(i) * math.log(i + 1)
	end
	Profiler.End("NarrowPhase")
end

local function integration()
	Profiler.Begin("Integration")
	for i = 1, 502 do
		local _ = math.sin(i * 0.05)
	end
	Profiler.End("Integration")
end

local function constraintSolver()
	Profiler.Begin("Constraints")
	for i = 1, 43 do
		local _ = math.cos(i * 0.03)
	end
	Profiler.End("Constraints")
end

local function doPhysics()
	Profiler.Begin("PhysicsStep") -- Parent task

	-- Child tasks automatically become nested under PhysicsStep
	broadPhase()
	narrowPhase()
	integration()
	constraintSolver()

	Profiler.End("PhysicsStep")
end

-- Heavy networking with sub-tasks
local function receivePackets()
	Profiler.Begin("Receive")
	local packets = {}
	for i = 1, 1200 do
		packets[i] = {
			id = i,
			data = string.format("packet_%d_%s", i, tostring(math.random())),
			timestamp = globals.RealTime(),
			size = i % 1500,
		}
	end
	Profiler.End("Receive")
end

local function processPackets()
	Profiler.Begin("Process")
	local processed = {}
	for i = 1, 600 do
		processed[i] = {
			index = math.floor(i / 16) * 16,
			payload = string.rep("data", i % 10),
			status = i % 2 == 0 and "valid" or "pending",
		}
	end
	Profiler.End("Process")
end

local function sendPackets()
	Profiler.Begin("Send")
	for i = 1, 15 do
		local _ = string.format("out_%d", i)
	end
	Profiler.End("Send")
end

local function doNetworking()
	Profiler.Begin("PacketProcess") -- Parent task

	-- Child tasks automatically become nested under PacketProcess
	receivePackets()
	processPackets()
	sendPackets()

	Profiler.End("PacketProcess")
end

-- CreateMove callback - runs every tick (shows tick-based ruler with T0, T1, T2...)
local function onCreateMove(cmd)
	Profiler.SetContext("tick")

	Profiler.Begin("TickProcess") -- Top-level tick work

	-- Compound tasks with heavy nested work
	doPathfinding() -- Contains PathCalculation + Optimization + Validation
	doPhysics() -- Contains BroadPhase + NarrowPhase + Integration + Constraints
	doNetworking() -- Contains Receive + Process + Send

	Profiler.End("TickProcess")
end

-- Draw callback - runs every frame (shows frame-based ruler with F0, F1, F2...)
local function onDraw()
	Profiler.SetContext("frame")

	Profiler.Begin("FrameProcess")

	-- Only do rendering in frame, no physics to prevent freezing
	doRendering() -- Contains Geometry + Shadows + Lighting + PostProcess

	Profiler.End("FrameProcess")

	Profiler.Draw() -- Draws the profiler UI
end

-- Unload callback
local function onUnload()
	print("[Profiler Example] unloaded")
	Profiler.SetVisible(false)
	Profiler.Shutdown()
	_G.PROFILER_EXAMPLE_LOADED = false
end

-- Register callbacks (no anonymous functions!)
callbacks.Register("CreateMove", SCRIPT_TAG, onCreateMove)
callbacks.Register("Draw", SCRIPT_TAG, onDraw)
callbacks.Register("Unload", SCRIPT_TAG, onUnload)

print("[Profiler Example] loaded. TICK context in CreateMove, FRAME context in Draw.")
print("  - Simplified names: 'Render.Geometry' shows as 'Geometry'")
print("  - Automatic nesting: child work automatically nests under parent")
print("  - Smart text layout with truncation for short blocks")
print("  - Data preserved on unpause - no crashes!")
