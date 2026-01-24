--[[
    Dual-Context Profiler Example
    Demonstrates simultaneous tick and frame profiling using context separation
]]

local Profiler = require("Profiler")

Profiler.SetVisible(true)

local function doPhysics()
	local result = 0
	for i = 1, 1000 do
		result = result + math.sqrt(i)
	end
	return result
end

local function doNetworking()
	local data = {}
	for i = 1, 500 do
		data[i] = string.format("packet_%d", i)
	end
	return data
end

local function doRendering()
	local vertices = {}
	for i = 1, 2000 do
		vertices[i] = { x = i * 0.5, y = i * 0.3, z = i * 0.7 }
	end
	return vertices
end

local function doUIUpdate()
	local elements = {}
	for i = 1, 100 do
		elements[i] = { id = i, visible = true }
	end
	return elements
end

local function onCreateMove(cmd)
	Profiler.SetContext("tick")

	Profiler.Begin("TickProcess")

	Profiler.Begin("Physics")
	doPhysics()
	Profiler.End()

	Profiler.Begin("Networking")
	doNetworking()
	Profiler.End()

	Profiler.End()
end

local function onDraw()
	Profiler.SetContext("frame")

	Profiler.Begin("FrameProcess")

	Profiler.Begin("Rendering")
	doRendering()
	Profiler.End()

	Profiler.Begin("UI")
	doUIUpdate()
	Profiler.End()

	Profiler.End()

	Profiler.Draw()
end

callbacks.Unregister("CreateMove", "DualContextProfiler_CreateMove")
callbacks.Unregister("Draw", "DualContextProfiler_Draw")

callbacks.Register("CreateMove", "DualContextProfiler_CreateMove", onCreateMove)
callbacks.Register("Draw", "DualContextProfiler_Draw", onDraw)

print("✅ Dual-context profiler example loaded")
print("📊 Tick context: Physics + Networking")
print("🎨 Frame context: Rendering + UI")
print("Context automatically switches based on callback")
