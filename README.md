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

-- Ultra-simple: Begin/End automatically detects system vs component
Profiler.Begin("aimbot")
    Profiler.Begin("targeting")
    -- ... your code ...
    Profiler.End() -- Automatically ends "targeting"
Profiler.End() -- Automatically ends "aimbot"

-- Or use explicit functions (no names needed when ending)
Profiler.BeginSystem("aimbot")
    Profiler.BeginComponent("targeting")
    -- ... your code ...
    Profiler.StopComponent() -- Automatically ends last component
Profiler.StopSystem() -- Automatically ends last system
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
    smoothingSpeed = 5.0,        -- How fast bars react (1-10)
    smoothingDecay = 1.0,        -- How fast bars shrink (0.5-2)
    systemMemoryMode = "system"  -- "system" or "components"
})

-- Individual settings
Profiler.SetSmoothingSpeed(5.0)              -- Animation speed
Profiler.SetSystemMemoryMode("system")       -- Memory calculation
Profiler.SetTextUpdateInterval(15)           -- Text update rate
Profiler.Reset()                             -- Clear all data
```

## 🎮 Controls

### New Simplified API

| Function                          | Description                          |
| --------------------------------- | ------------------------------------ |
| `Profiler.SetVisible(true/false)` | Show/hide profiler                   |
| `Profiler.Enable()`               | Quick enable                         |
| `Profiler.Disable()`              | Quick disable                        |
| `Profiler.Begin("name")`          | Auto-start system or component       |
| `Profiler.End()`                  | Auto-end last started item           |
| `Profiler.BeginSystem("name")`    | Explicitly start measuring system    |
| `Profiler.BeginComponent("name")` | Explicitly start measuring component |
| `Profiler.StopSystem()`           | End last started system              |
| `Profiler.StopComponent()`        | End last started component           |

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

### Animation Speed

```
smoothingSpeed:  1.0 ←────────────→ 10.0
                slow    balanced    fast
                 🐌        🎯        ⚡
```

### Peak Decay

```
smoothingDecay:  0.5 ←────────────→ 2.0
                slow    balanced    fast
                 📈        🎯        📉
              (peaks stay) (balanced) (peaks fade)
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
| `smoothingSpeed`     | 5.0      | 0.1-20.0                    | 🐌 ←→ ⚡ (spike response)   |
| `smoothingDecay`     | 1.0      | 0.1-20.0                    | 📈 ←→ 📉 (peak persistence) |
| `textUpdateInterval` | 15       | 1-120                       | 📱 ←→ 📺 (update frequency) |
| `windowSize`         | 60       | 1-300                       | ⚡ ←→ 🧘 (averaging window) |
| `sortMode`           | "size"   | "size", "static", "reverse" | 📊 📋 🔄                    |
| `systemMemoryMode`   | "system" | "system", "components"      | 🎯 ➕                       |

## 💡 Tips

**For Performance Hunting:**

```lua
Profiler.Setup({
    smoothingSpeed = 8.0,    -- Fast spike detection
    smoothingDecay = 0.5,    -- Keep peaks visible longer
    systemMemoryMode = "system"
})
```

**For Smooth Monitoring:**

```lua
Profiler.Setup({
    smoothingSpeed = 3.0,    -- Smooth animations
    smoothingDecay = 1.5,    -- Balanced decay
    systemMemoryMode = "components"
})
```

## 📝 Examples

### New Simplified API Examples

**Ultra-Simple Usage:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your aimbot - super clean!
Profiler.Begin("aimbot")
    Profiler.Begin("get_targets")
    local targets = GetTargets()
    Profiler.End() -- Automatically ends "get_targets"

    Profiler.Begin("calculate_aim")
    local angles = CalculateAim(targets[1])
    Profiler.End() -- Automatically ends "calculate_aim"
Profiler.End() -- Automatically ends "aimbot"
```

**Explicit Simplified API:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Multiple systems - no names needed when ending
Profiler.BeginSystem("movement")
    Profiler.BeginComponent("bhop")
    -- ... bhop code ...
    Profiler.StopComponent() -- Ends last component
Profiler.StopSystem() -- Ends last system

Profiler.BeginSystem("esp")
    Profiler.BeginComponent("players")
    -- ... player ESP ...
    Profiler.StopComponent() -- Ends last component
Profiler.StopSystem() -- Ends last system
```

### Original API Examples

**Basic Usage:**

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your aimbot
Profiler.StartSystem("aimbot")
    Profiler.StartComponent("get_targets")
    local targets = GetTargets()
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
Profiler.Begin("calculations")
    Profiler.Begin("pathfinding")
    local result = ExpensiveFunction()
    Profiler.End() -- Ends pathfinding
Profiler.End() -- Ends calculations
```

---

**Made with ❤️ by titaniummachine1**
