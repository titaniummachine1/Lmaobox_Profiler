# 🎯 Profiler - Performance Monitoring for Lmaobox

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

[![Download Latest](https://img.shields.io/github/downloads/titaniummachine1/Lmaobox_Profiler/total.svg?style=for-the-badge&logo=download&label=Download%20Latest)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

A lightweight, real-time performance profiler that shows you exactly what's eating your CPU and memory.

## 🚀 Quick Start

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

| Function                          | Description               |
| --------------------------------- | ------------------------- |
| `Profiler.SetVisible(true/false)` | Show/hide profiler        |
| `Profiler.Enable()`               | Quick enable              |
| `Profiler.Disable()`              | Quick disable             |
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

| Setting              | Default  | Range                       | Description                       |
| -------------------- | -------- | --------------------------- | --------------------------------- |
| `smoothingSpeed`     | 5.0      | 0.1-20.0                    | How fast bars grow on spikes      |
| `smoothingDecay`     | 1.0      | 0.1-20.0                    | How fast bars shrink after spikes |
| `textUpdateInterval` | 15       | 1-120                       | Text update rate (frames)         |
| `windowSize`         | 60       | 1-300                       | Averaging window (frames)         |
| `sortMode`           | "size"   | "size", "static", "reverse" | Bar sorting                       |
| `systemMemoryMode`   | "system" | "system", "components"      | Memory calculation                |

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
local result = Profiler.Time("calculations", "pathfinding", function()
    return ExpensiveFunction()
end)
```

---

**Made with ❤️ by titaniummachine1**
