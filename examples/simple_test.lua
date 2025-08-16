-- Simple Profiler Test
-- Lightweight example to test the profiler without lag

-- Load the profiler
local Profiler = require("Profiler")
Profiler.SetVisible(true)

print("✅ Simple profiler test loaded!")

-- Useful trace testing functions
local function PerformTraceTests()
    local me = entities.GetLocalPlayer()
    if not me then return end
    
    local source = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local viewAngles = engine.GetViewAngles()
    local forward = viewAngles:Forward()
    
    local traces = {}
    
    -- Test 50 trace lines in different directions
    for i = 1, 50 do
        -- Vary the direction slightly for each trace
        local angleOffset = (i - 25) * 2 -- -48 to +48 degrees spread
        local yawOffset = math.rad(angleOffset)
        
        -- Calculate direction with offset
        local cos_yaw = math.cos(viewAngles.yaw + yawOffset)
        local sin_yaw = math.sin(viewAngles.yaw + yawOffset)
        local cos_pitch = math.cos(math.rad(viewAngles.pitch))
        
        local direction = Vector3(
            cos_yaw * cos_pitch,
            sin_yaw * cos_pitch,
            -math.sin(math.rad(viewAngles.pitch))
        )
        
        local destination = source + direction * 1000
        local trace = engine.TraceLine(source, destination, MASK_SHOT_HULL)
        
        if trace.entity ~= nil then
            traces[i] = {
                entity = trace.entity:GetClass(),
                distance = trace.fraction * 1000,
                angle = angleOffset
            }
        end
    end
    
    return traces
end

local function EntityScanning()
    -- Scan for entities and do calculations
    local players = entities.FindByClass("CTFPlayer")
    local buildings = entities.FindByClass("CObjectSentrygun")
    
    local calculations = {}
    
    for i, entity in ipairs(players) do
        if entity:IsAlive() and not entity:IsDormant() then
            local origin = entity:GetAbsOrigin()
            local distance = origin:Length()
            calculations[#calculations + 1] = {
                type = "player",
                distance = distance,
                health = entity:GetHealth()
            }
        end
    end
    
    for i, building in ipairs(buildings) do
        if building:IsAlive() then
            local origin = building:GetAbsOrigin()
            local distance = origin:Length()
            calculations[#calculations + 1] = {
                type = "sentry",
                distance = distance,
                level = building:GetPropInt("m_iUpgradeLevel")
            }
        end
    end
    
    return calculations
end

local function ManualTest()
    Profiler.Begin("manual_trace_work")
    
    -- Do the actual trace work
    local traces = PerformTraceTests()
    local entities = EntityScanning()
    
    -- Process results
    local hitCount = 0
    for i, trace in pairs(traces) do
        if trace then
            hitCount = hitCount + 1
        end
    end
    
    Profiler.End()
    return hitCount, #entities
end

-- Register useful callbacks
callbacks.Register("CreateMove", "simple_test", function(cmd)
    PerformTraceTests()
    EntityScanning()
    
    -- Manual test every 60 frames
    if globals.FrameCount() % 60 == 0 then
        ManualTest()
    end
end)

callbacks.Register("Draw", "simple_test", function()
    -- Simple FPS display
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, string.format("FPS: %d | Trace Test", math.floor(1 / globals.FrameTime())))
    
    -- Do trace work in draw too
    PerformTraceTests()
end)

callbacks.Register("Unload", "simple_test", function()
    print("Simple test unloaded")
end)

print("Simple test ready - should see functions in profiler!")
