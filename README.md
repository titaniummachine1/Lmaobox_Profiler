# 🎯 Profiler - Performance Monitoring for Lmaobox

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

[![Download Latest](https://img.shields.io/github/downloads/titaniummachine1/Lmaobox_Profiler/total.svg?style=for-the-badge&logo=download&label=Download%20Latest)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

A lightweight, real-time performance profiler that shows you exactly what's eating your CPU and memory.

## 🚀 Quick Start

### New Simplified API (Recommended)

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
--Profiler.SetVisible(true)

-- Measure your code
Profiler.StartSystem("aimbot")
    Profiler.StartComponent("targeting")
    -- ... your code ...
    Profiler.EndComponent("targeting")
Profiler.EndSystem("aimbot")
```

## ⚙️ Configuration

```lua
-- Quick setup
Profiler.Setup({
    visible = true,
    smoothingSpeed = 15.0,       -- Percentage per frame (1-50, higher = more responsive)
    smoothingDecay = 8.0,        -- Percentage per frame when decaying (1-50)
    systemMemoryMode = "system", -- "system" or "components"
    compensateOverhead = true    -- Subtract profiler's own memory usage
})

-- Individual settings
Profiler.SetSmoothingSpeed(15.0)             -- Animation speed (1-50% per frame)
Profiler.SetSmoothingDecay(8.0)              -- Decay speed (1-50% per frame)
Profiler.SetSystemMemoryMode("system")       -- Memory calculation
Profiler.SetOverheadCompensation(true)       -- Enable overhead compensation
Profiler.SetTextUpdateInterval(15)           -- Text update rate
Profiler.Reset()                             -- Clear all data
```

## 🎮 Controls

### New Simplified API

| Function                          | Description                |
| --------------------------------- | -------------------------- |
| `Profiler.SetVisible(true/false)` | Show/hide profiler         |
| `Profiler.Enable()`               | Quick enable               |
| `Profiler.Disable()`              | Quick disable              |
| `Profiler.BeginSystem("name")`    | Start measuring system     |
| `Profiler.EndSystem()`            | End last started system    |
| `Profiler.Begin("name")`          | Start measuring component  |
| `Profiler.End()`                  | End last started component |

### Original API (Still Supported)

| Function                          | Description               |
| --------------------------------- | ------------------------- |
| `Profiler.StartSystem("name")`    | Start measuring system    |
| `Profiler.StartComponent("name")` | Start measuring component |
| `Profiler.EndComponent("name")`   | End measuring component   |
| `Profiler.EndSystem("name")`      | End measuring system      |

## 🎨 What You See

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
| `smoothingSpeed`     | 15.0     | 1.0-50.0                    | 🐌 ←→ ⚡ (spike response)   |
| `smoothingDecay`     | 8.0      | 1.0-50.0                    | 📈 ←→ 📉 (peak persistence) |
| `textUpdateInterval` | 15       | 1-120                       | 📱 ←→ 📺 (update frequency) |
| `windowSize`         | 60       | 1-300                       | ⚡ ←→ 🧘 (averaging window) |
| `sortMode`           | "size"   | "size", "static", "reverse" | 📊 📋 🔄                    |
| `systemMemoryMode`   | "system" | "system", "components"      | 🎯 ➕                       |
| `compensateOverhead` | true     | true, false                 | 📏 ❌ (accuracy vs raw)     |

## 💡 Tips

**For Performance Hunting:**

```lua
Profiler.Setup({
    smoothingSpeed = 25.0,   -- Fast spike detection
    smoothingDecay = 5.0,    -- Keep peaks visible longer
    systemMemoryMode = "system"
})
```

**For Smooth Monitoring:**

```lua
Profiler.Setup({
    smoothingSpeed = 8.0,    -- Smooth animations
    smoothingDecay = 12.0,   -- Balanced decay
    systemMemoryMode = "components"
})
```

## 📝 Examples

### New Simplified API Examples

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

### Original API Examples

**Basic Usage:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your aimbot
Profiler.StartSystem("aimbot")
    local targets

    Profiler.StartComponent("get_targets")
    targets = GetTargets()
    Profiler.EndComponent("get_targets")

    Profiler.StartComponent("calculate_aim")
    local angles = CalculateAim(targets[1])
    Profiler.EndComponent("calculate_aim")
Profiler.EndSystem("aimbot")
```

**Multiple Systems:**

```lua
-- Movement
Profiler.StartSystem("movement")
    Profiler.StartComponent("bhop")
    -- ... bhop code ...
    Profiler.EndComponent("bhop")
Profiler.EndSystem("movement")

-- ESP
Profiler.StartSystem("esp")
    Profiler.StartComponent("players")
    -- ... player ESP ...
    Profiler.EndComponent("players")
Profiler.EndSystem("esp")
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

---

**Made with ❤️ by titaniummachine1**
