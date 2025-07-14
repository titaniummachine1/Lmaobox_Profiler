# 🎯 Profiler - Performance Monitoring for Lmaobox

A lightweight, real-time performance profiler that shows you exactly what's eating your CPU and memory.

## 📦 Quick Start

```lua
local Profiler = require("Profiler")

-- Turn on the profiler
Profiler.SetVisible(true)

-- Measure your code
Profiler.StartSystem("aimbot")
    Profiler.StartComponent("target_selection")
    -- ... your targeting code ...
    Profiler.EndComponent("target_selection")

    Profiler.StartComponent("prediction")
    -- ... your prediction code ...
    Profiler.EndComponent("prediction")
Profiler.EndSystem("aimbot")

-- The profiler automatically draws itself on screen
```

## 🎮 Basic Controls

### Turn Profiler On/Off

```lua
Profiler.SetVisible(true)   -- Show profiler
Profiler.SetVisible(false)  -- Hide profiler

-- Or use shortcuts
Profiler.Enable()   -- Show profiler
Profiler.Disable()  -- Hide profiler
```

### Quick Setup

```lua
-- Configure everything at once
Profiler.Setup({
    visible = true,
    smoothingSpeed = 5.0,
    smoothingDecay = 1.0,
    systemMemoryMode = "system"
})
```

## 📊 Visual Settings

### Animation Speed

Controls how fast the bars react to performance changes:

```lua
-- How fast bars grow when performance spikes
Profiler.SetSmoothingSpeed(5.0)  -- Default: 5.0
-- 1.0 = Very slow, smooth
-- 5.0 = Balanced (recommended)
-- 10.0 = Very fast, responsive

-- How fast bars shrink after spikes
Profiler.SetSmoothingDecay(1.0)  -- Default: 1.0
-- 0.5 = Very slow decay (peaks stay visible longer)
-- 1.0 = Balanced (recommended)
-- 2.0 = Fast decay (peaks disappear quickly)
```

### Text Update Rate

Controls how often the numbers change:

```lua
Profiler.SetTextUpdateInterval(15)  -- Default: 15 frames
-- 6 = Update ~10 times per second (jittery)
-- 15 = Update 4 times per second (smooth, recommended)
-- 30 = Update 2 times per second (very stable)
```

### Display Options

```lua
-- How many systems to show at once
Profiler.SetWindowSize(60)  -- Default: 60 frames (1 second average)
-- 30 = 0.5 second average (more reactive)
-- 60 = 1 second average (recommended)
-- 120 = 2 second average (very stable)

-- Sort order
Profiler.SetSortMode("size")     -- Biggest problems first (recommended)
Profiler.SetSortMode("static")   -- Order you measured them
Profiler.SetSortMode("reverse")  -- Smallest problems first
```

## 🔧 Memory Measurement Modes

Choose how system memory is calculated:

```lua
-- Show actual system memory usage (DEFAULT)
Profiler.SetSystemMemoryMode("system")
-- System bar shows: "How much memory did this whole system actually use?"
-- Good for: Seeing true memory bounds and overhead

-- Show sum of component memory
Profiler.SetSystemMemoryMode("components")
-- System bar shows: "Sum of all component memory usage"
-- Good for: Seeing how components add up
```

**Example:**

- `"system"` mode: `aimbot 25.3KB` (actual system memory footprint)
- `"components"` mode: `aimbot 18.7KB` (sum of all aimbot components)

## 🛠️ Advanced Usage

### Nested Systems

```lua
Profiler.StartSystem("main_loop")
    Profiler.StartComponent("input_processing")
    -- ... input code ...
    Profiler.EndComponent("input_processing")

    Profiler.StartSystem("aimbot")  -- Nested system
        Profiler.StartComponent("targeting")
        -- ... targeting code ...
        Profiler.EndComponent("targeting")
    Profiler.EndSystem("aimbot")
Profiler.EndSystem("main_loop")
```

### Quick Function Timing

```lua
-- Time a single function
local result = Profiler.Time("calculations", "pathfinding", function()
    return expensive_pathfinding_function()
end)

-- Time with default system name
local result = Profiler.Time("database_query", function()
    return query_database()
end)
```

### Reset Everything

```lua
Profiler.Reset()  -- Clear all measurements and start fresh
```

## 📋 Complete Configuration Reference

### All Settings with Defaults

```lua
Profiler.Setup({
    -- Basic
    visible = false,                    -- Show/hide profiler

    -- Visual smoothing
    smoothingSpeed = 5.0,              -- How fast bars grow (0.1-20.0)
    smoothingDecay = 1.0,              -- How fast bars shrink (0.1-20.0)
    textUpdateInterval = 15,           -- Text update rate in frames (1-120)

    -- Display
    windowSize = 60,                   -- Averaging window in frames (1-300)
    sortMode = "size",                 -- "size", "static", "reverse"
    systemHeight = 48,                 -- Bar height in pixels
    fontSize = 12,                     -- Text size
    maxSystems = 20,                   -- Max systems to display
    textPadding = 6,                   -- Text padding in pixels

    -- Memory measurement
    systemMemoryMode = "system",       -- "system" or "components"
})
```

### Individual Setting Functions

```lua
-- Visual
Profiler.SetSmoothingSpeed(5.0)        -- Bar growth speed
Profiler.SetSmoothingDecay(1.0)        -- Bar shrink speed
Profiler.SetTextUpdateInterval(15)     -- Text update rate

-- Display
Profiler.SetWindowSize(60)             -- Averaging window
Profiler.SetSortMode("size")           -- Sort order

-- Memory
Profiler.SetSystemMemoryMode("system") -- Memory calculation mode
```

## 🎨 What You'll See

### System Bars (Grey Background)

- **Full width bars** spanning the entire screen
- **System name** on the left (e.g., "aimbot", "movement")
- **Total memory usage** below the name
- **Contains all components** for that system

### Component Bars (Colored)

- **Nested inside system bars** to show hierarchy
- **Proportional width** based on memory usage
- **Component name** at the top
- **Memory amount** in the middle (e.g., "15.2KB")
- **Timing info** at the bottom with red background (if >0.01ms)

### Colors

- **System bars**: Dark grey background
- **Component bars**: Auto-generated colors based on component name
- **Text**: White for names, light grey for memory, white on red for timing

## 🚀 Performance Tips

### For Best Results:

1. **Use descriptive names**: `"target_selection"` not `"func1"`
2. **Measure at the right level**: Don't measure every tiny function
3. **Use system grouping**: Group related components under systems
4. **Check both memory modes**: Compare `"system"` vs `"components"` modes

### Recommended Settings:

```lua
-- For performance hunting (catch all spikes)
Profiler.Setup({
    visible = true,
    smoothingSpeed = 8.0,    -- Fast spike detection
    smoothingDecay = 0.5,    -- Slow decay (peaks stay visible)
    systemMemoryMode = "system"
})

-- For stable monitoring (smooth display)
Profiler.Setup({
    visible = true,
    smoothingSpeed = 3.0,    -- Smooth scaling
    smoothingDecay = 1.5,    -- Balanced decay
    systemMemoryMode = "components"
})
```

## 📝 Examples

### Basic Aimbot Profiling

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your aimbot code
Profiler.StartSystem("aimbot")
    Profiler.StartComponent("get_targets")
    local targets = GetValidTargets()
    Profiler.EndComponent("get_targets")

    Profiler.StartComponent("calculate_angles")
    local angles = CalculateAimAngles(targets[1])
    Profiler.EndComponent("calculate_angles")

    Profiler.StartComponent("smooth_aim")
    ApplyAimSmoothing(angles)
    Profiler.EndComponent("smooth_aim")
Profiler.EndSystem("aimbot")
```

### Multiple Systems

```lua
-- Movement system
Profiler.StartSystem("movement")
    Profiler.StartComponent("bhop")
    -- ... bhop code ...
    Profiler.EndComponent("bhop")
Profiler.EndSystem("movement")

-- ESP system
Profiler.StartSystem("esp")
    Profiler.StartComponent("player_esp")
    -- ... player ESP code ...
    Profiler.EndComponent("player_esp")
Profiler.EndSystem("esp")
```

---

**Made with ❤️ by titaniummachine1**
