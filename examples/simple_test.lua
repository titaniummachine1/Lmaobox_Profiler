-- Simple Profiler Test
-- Lightweight example to test the profiler without lag

-- Load the profiler
local Profiler = require("Profiler")
Profiler.SetVisible(true)

print("✅ Simple profiler test loaded!")

-- Simple test functions that won't lag
local function LightWork()
    local sum = 0
    for i = 1, 10 do
        sum = sum + math.sin(i)
    end
    return sum
end

local function MediumWork()
    local result = {}
    for i = 1, 20 do
        result[i] = math.sqrt(i) * 2
    end
    return result
end

local function ManualTest()
    Profiler.Begin("manual_test")
    
    local total = 0
    for i = 1, 15 do
        total = total + math.cos(i)
    end
    
    Profiler.End()
    return total
end

-- Register lightweight callbacks
callbacks.Register("CreateMove", "simple_test", function(cmd)
    LightWork()
    MediumWork()
    
    -- Manual test every 60 frames
    if globals.FrameCount() % 60 == 0 then
        ManualTest()
    end
end)

callbacks.Register("Draw", "simple_test", function()
    -- Simple FPS display
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, string.format("FPS: %d | Simple Test", math.floor(1 / globals.FrameTime())))
    
    -- Light work
    LightWork()
end)

callbacks.Register("Unload", "simple_test", function()
    print("Simple test unloaded")
end)

print("Simple test ready - should see functions in profiler!")
