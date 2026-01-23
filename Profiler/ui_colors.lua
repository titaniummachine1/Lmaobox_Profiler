--[[
    UI Colors Module - Memory-Based Color Scaling
    Provides color schemes and time/memory formatting
    
    Time uses MICROSECONDS (µs) as base unit - os.clock() has sub-µs precision
]]

local UIColors = {}

-- Constants
local KB = 1024
local MB = 1024 * 1024

local LOW_MEMORY_THRESHOLD = 10 * KB      -- 10 KB
local HIGH_MEMORY_THRESHOLD = 10 * MB     -- 10 MB

-- Pastel colors for low-memory blocks
local PASTEL_COLORS = {
    { r = 100, g = 180, b = 255 },
    { r = 150, g = 220, b = 150 },
    { r = 180, g = 150, b = 255 },
    { r = 255, g = 180, b = 150 },
    { r = 150, g = 200, b = 200 },
    { r = 200, g = 180, b = 220 },
    { r = 180, g = 200, b = 150 },
    { r = 220, g = 180, b = 200 },
    { r = 150, g = 180, b = 220 },
    { r = 200, g = 200, b = 150 },
}

-- Hash string for deterministic color
local function hashString(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return hash
end

function UIColors.GetAestheticColor(name)
    local hash = hashString(name or "unknown")
    local colorIndex = (hash % #PASTEL_COLORS) + 1
    local color = PASTEL_COLORS[colorIndex]
    return color.r, color.g, color.b, 200
end

local function lerpColor(r1, g1, b1, r2, g2, b2, t)
    t = math.max(0, math.min(1, t))
    return
        math.floor(r1 + (r2 - r1) * t),
        math.floor(g1 + (g2 - g1) * t),
        math.floor(b1 + (b2 - b1) * t)
end

function UIColors.GetMemoryColor(memBytes, name)
    local absMem = math.abs(memBytes or 0)
    
    if absMem < LOW_MEMORY_THRESHOLD then
        return UIColors.GetAestheticColor(name)
    end
    
    if absMem >= HIGH_MEMORY_THRESHOLD then
        return 255, 50, 50, 255
    end
    
    local logLow = math.log(LOW_MEMORY_THRESHOLD)
    local logHigh = math.log(HIGH_MEMORY_THRESHOLD)
    local logMem = math.log(absMem)
    
    local t = (logMem - logLow) / (logHigh - logLow)
    t = math.max(0, math.min(1, t))
    
    if t < 0.5 then
        local t2 = t * 2
        local r, g, b = lerpColor(255, 200, 50, 255, 120, 50, t2)
        return r, g, b, 220
    else
        local t2 = (t - 0.5) * 2
        local r, g, b = lerpColor(255, 120, 50, 255, 50, 50, t2)
        return r, g, b, 240
    end
end

function UIColors.GetHeightForMemory(memBytes, baseHeight)
    baseHeight = baseHeight or 16
    local absMem = math.abs(memBytes or 0)
    
    if absMem < LOW_MEMORY_THRESHOLD then
        return baseHeight
    end
    
    local logMem = math.log(absMem / LOW_MEMORY_THRESHOLD)
    local logMax = math.log(HIGH_MEMORY_THRESHOLD / LOW_MEMORY_THRESHOLD)
    
    local growthFactor = logMem / logMax
    growthFactor = math.max(0, math.min(1, growthFactor))
    
    return baseHeight + (baseHeight * growthFactor)
end

function UIColors.FormatMemory(memBytes)
    local absMem = math.abs(memBytes or 0)
    local sign = memBytes < 0 and "-" or ""
    
    if absMem >= MB then
        return string.format("%s%.2f MB", sign, absMem / MB)
    elseif absMem >= KB then
        return string.format("%s%.2f KB", sign, absMem / KB)
    else
        return string.format("%s%d B", sign, absMem)
    end
end

-- Format time - INPUT IS SECONDS, OUTPUT IS µs/ms
-- os.clock() returns seconds with µs precision
function UIColors.FormatTime(seconds)
    if not seconds or seconds ~= seconds then
        return "0µs"
    end
    
    -- Convert to microseconds (multiply by 1,000,000)
    local microseconds = seconds * 1000000
    
    -- Show milliseconds if >= 1000µs (1ms)
    if microseconds >= 1000 then
        return string.format("%.2fms", microseconds / 1000)
    else
        -- Show microseconds with decimal for precision
        return string.format("%.0fµs", microseconds)
    end
end

-- Format time for ruler (needs more precision)
function UIColors.FormatTimeRuler(seconds)
    if not seconds or seconds ~= seconds then
        return "0"
    end
    
    local microseconds = seconds * 1000000
    
    if microseconds >= 1000 then
        return string.format("%.1fms", microseconds / 1000)
    elseif microseconds >= 1 then
        return string.format("%.0fµs", microseconds)
    else
        -- Sub-microsecond
        return string.format("%.2fµs", microseconds)
    end
end

return UIColors
