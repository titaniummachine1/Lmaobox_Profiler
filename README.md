# 🎯 Profiler - Performance Monitoring for Lmaobox

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

[![Download Latest](https://img.shields.io/badge/Download%20Latest-Profiler.lua-brightgreen?style=for-the-badge&logo=download)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

A lightweight, real-time performance profiler that shows you exactly what's eating your CPU and memory. Features both manual profiling and automatic function hooking for comprehensive performance analysis.

## 🚀 Quick Start

### Automatic Function Profiling (NEW!)

The profiler now automatically hooks and profiles all user functions, similar to Roblox's microprofiler:

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- That's it! All your functions are automatically profiled
-- No need to manually wrap code - just run your scripts normally
```

### Manual Profiling API

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Explicit systems, Begin for components
Profiler.BeginSystem("aimbot")
    Profiler.Begin("targeting")
    -- ... your code ...
    Profiler.End() -- Ends component
Profiler.EndSystem() -- Ends system
```

### Original API (Still Supported)

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Measure your code
Profiler.StartSystem("aimbot")
    Profiler.StartComponent("targeting")
    -- ... your code ...
    Profiler.EndComponent("targeting")
Profiler.EndSystem("aimbot")
```

## 🎮 Controls

### UI Navigation

- **Drag**: Pan the virtual board around
- **Q/E**: Zoom in/out (zooms towards mouse cursor)
- **P**: Pause/resume recording
- **Mouse Wheel**: Alternative zoom method
- **Frame Timeline**: Click on frame pillars to jump to that time

### Virtual Board System

The profiler uses a virtual board coordinate system where all UI elements are positioned on a fixed 2000x2000 pixel board, then transformed to screen coordinates. This provides:

- **Smooth Panning**: Natural drag-to-pan movement
- **Zoom Compensation**: Content stays under mouse cursor when zooming
- **Y-Axis Clamping**: Content can't overlap the top UI bar
- **Predictable Movement**: All elements move together consistently

## 🧪 Testing

### Ultra-Aggressive Test

Use `examples/simple_test.lua` to test the profiler with functions that are guaranteed to be visible:

```lua
-- This test creates functions that take 50-100+ milliseconds each
-- Perfect for verifying the profiler is working correctly
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Run the test
-- Functions include: UltraHeavyCalculation, UltraHeavyStringWork, etc.
```

**Test Features:**

- **5 Million iterations** of complex math operations
- **1 Million string concatenations** (very slow in Lua)
- **500K table entries** with sorting
- **Artificial delays** forcing 50ms minimum duration
- **Simulated file/network operations**

### Expected Results

With the current time scale (100 px/s):

- **50ms function**: 5 pixels wide (clearly visible)
- **100ms function**: 10 pixels wide (very visible)
- **Multiple functions**: Overlapping bars with different colors

## ⚙️ Configuration

```lua
-- Quick setup
Profiler.Setup({
    visible = true,
    smoothingSpeed = 2.5,        -- Percentage per frame (1-50, higher = more responsive)
    smoothingDecay = 1.5,        -- Percentage per frame when decaying (1-50)
    systemMemoryMode = "system", -- "system" or "components"
    compensateOverhead = true    -- Subtract profiler's own memory usage
})

-- Individual settings
Profiler.SetSmoothingSpeed(2.5)              -- Animation speed (1-50% per frame)
Profiler.SetSmoothingDecay(1.5)              -- Decay speed (1-50% per frame)
Profiler.SetSystemMemoryMode("system")       -- Memory calculation
Profiler.SetOverheadCompensation(true)       -- Enable overhead compensation
Profiler.SetTextUpdateInterval(15)           -- Text update rate
Profiler.Reset()                             -- Clear all data
```

## 🎨 What You See

### Automatic Profiling View

- **Script Headers** (green bars): Each script gets its own section
- **Function Bars** (colored): Individual functions with timing and names
- **Function Count**: Shows how many functions were profiled per script
- **Time Scale**: 100 pixels per second (configurable)
- **Zoom Level**: Current zoom factor displayed

### Manual Profiling View

- **System bars** (grey, full width): Complete systems like "aimbot", "movement"
- **Component bars** (colored, nested): Individual parts within systems
- **Memory values**: Real KB usage for each part
- **Timing info**: Millisecond timing with red highlights

## 📊 Settings Reference

### New Smoothing System

The profiler now uses a **percentage-based smoothing system** that's more predictable and responsive:

- **smoothingSpeed**: Percentage of remaining distance to move per frame (1-50%)
- **smoothingDecay**: Percentage to move when bars are shrinking (1-50%)
- **Additional filtering**: Multi-frame weighted average reduces jitter

### Animation Speed

```
smoothingSpeed:  5.0 ←────────────→ 30.0
                smooth   balanced   responsive
                 🐌        🎯        ⚡
              (gradual)  (default)  (snappy)
```

### Peak Decay

```
smoothingDecay:  3.0 ←────────────→ 20.0
                slow    balanced    fast
                 📈        🎯        📉
              (peaks stay) (default) (peaks fade)
```

### Text Updates

```
textUpdateInterval: 6 ←──────────→ 30 frames
                   10/sec  4/sec  2/sec
                    📱      🎯      📺
                  (jittery) (smooth) (stable)
```

### Memory Modes

```
"system":     [████████████████] 25.3KB  ← actual system memory
"components": [██████████]       18.7KB  ← sum of components
```

### Complete Settings Table

| Setting              | Default  | Range                       | Visual Guide                |
| -------------------- | -------- | --------------------------- | --------------------------- |
| `smoothingSpeed`     | 2.5      | 1.0-50.0                    | 🐌 ←→ ⚡ (spike response)   |
| `smoothingDecay`     | 1.5      | 1.0-50.0                    | 📈 ←→ 📉 (peak persistence) |
| `textUpdateInterval` | 20       | 1-120                       | 📱 ←→ 📺 (update frequency) |
| `windowSize`         | 60       | 1-300                       | ⚡ ←→ 🧘 (averaging window) |
| `sortMode`           | "size"   | "size", "static", "reverse" | 📊 📋 🔄                    |
| `systemMemoryMode`   | "system" | "system", "components"      | 🎯 ➕                       |
| `compensateOverhead` | true     | true, false                 | 📏 ❌ (accuracy vs raw)     |

## 💡 Tips

**For Performance Hunting:**

```lua
Profiler.Setup({
    smoothingSpeed = 12.0,   -- Fast spike detection
    smoothingDecay = 3.0,    -- Keep peaks visible longer
    systemMemoryMode = "system"
})
```

**For Smooth Monitoring:**

```lua
Profiler.Setup({
    smoothingSpeed = 2.5,    -- Very smooth animations (default)
    smoothingDecay = 1.5,    -- Slow decay (default)
    systemMemoryMode = "components"
})
```

**For Function Analysis:**

```lua
-- The automatic profiling will show you:
-- - Which functions are taking the most time
-- - Function call hierarchies
-- - Memory usage per function
-- - Script-by-script breakdown
```

## 📝 Examples

### Automatic Profiling (Recommended)

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Just run your code normally - everything is automatically profiled!
function MyExpensiveFunction()
    -- This function will automatically appear in the profiler
    for i = 1, 1000000 do
        math.sin(i) * math.cos(i)
    end
end

-- Call it normally
MyExpensiveFunction()
```

### Manual Profiling Examples

**Simplified Usage:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your aimbot - clean and explicit!
Profiler.BeginSystem("aimbot")
    local targets

    Profiler.Begin("get_targets")
    targets = GetTargets()
    Profiler.End() -- Ends component

    Profiler.Begin("calculate_aim")
    local angles = CalculateAim(targets[1])
    Profiler.End() -- Ends component
Profiler.EndSystem() -- Ends system
```

**Multiple Systems:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Multiple systems - no names needed when ending
Profiler.BeginSystem("movement")
    Profiler.Begin("bhop")
    -- ... bhop code ...
    Profiler.End() -- Ends component
Profiler.EndSystem() -- Ends system

Profiler.BeginSystem("esp")
    Profiler.Begin("players")
    -- ... player ESP ...
    Profiler.End() -- Ends component
Profiler.EndSystem() -- Ends system
```

**Quick Function Timing:**

```lua
-- Using the Time helper (works with both APIs)
local result = Profiler.Time("calculations", "pathfinding", function()
    return ExpensiveFunction()
end)

-- Or with the new simplified API
Profiler.BeginSystem("calculations")
    Profiler.Begin("pathfinding")
    ExpensiveFunction()
    Profiler.End() -- Ends component
Profiler.EndSystem() -- Ends system
```

## 🔧 Technical Details

### Module Structure

- **Main.lua**: Entry point and API
- **Shared.lua**: Shared runtime data (renamed from globals.lua)
- **microprofiler.lua**: Automatic function hooking system
- **ui_body_simple.lua**: Virtual board UI system
- **ui_top.lua**: Top bar with frame timeline
- **config.lua**: Configuration settings

### External Dependencies

The profiler safely imports the external `globals` library (providing `RealTime()` and `FrameTime()`) using `pcall` to prevent errors if the library isn't available.

### Performance Impact

- **Automatic profiling**: Minimal overhead, hooks only user functions
- **Manual profiling**: Near-zero overhead when disabled
- **UI rendering**: Optimized for 60fps with configurable update rates

---

**Made with ❤️ by titaniummachine1**
