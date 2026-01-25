# 🎯 Profiler - Performance Monitoring for Lmaobox

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

[![Download Latest](https://img.shields.io/badge/Download%20Latest-Profiler.lua-brightgreen?style=for-the-badge&logo=download)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

A lightweight, microsecond-precision performance profiler that shows exactly what's consuming your CPU and memory. Features dual-context tick/frame profiling, automatic function hooking, and a visual timeline with accurate ruler boundaries.

## ⚡ Timing Server (Recommended)

The profiler **works without** the timing server but uses `os.clock()` which has limited precision (~10ms). For **microsecond-level accuracy**, run the timing server:

### Using Pre-built Binary (Quick)

```bash
cd timing_server
timing_server.exe  # Runs on http://127.0.0.1:9876
```

### Compile Yourself (Trustless)

**If you don't trust random executables**, rebuild everything yourself - the repo contains complete source:

```bash
cd timing_server
cargo build --release
# Binary: target/release/timing_server.exe
```

**Requirements:** Rust toolchain ([rustup.rs](https://rustup.rs))

The timing server provides nanosecond-precision timestamps via HTTP. The profiler automatically detects and uses it when available, falling back to `os.clock()` gracefully.

## 📦 Installation

**Option 1: Download from releases** (easiest)

1. Download `Profiler.lua` from [latest release](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest)
2. Place in `%LOCALAPPDATA%\lua\`
3. Load: `lua_load Profiler` or `require("Profiler")` in your script

**Option 2: Build from source** (full transparency)

```bash
git clone https://github.com/titaniummachine1/Lmaobox_Profiler.git
cd Lmaobox_Profiler
node bundle.js  # Requires Node.js
# Output: Profiler.lua (automatically copied to %LOCALAPPDATA%\lua\)
```

Everything is open source - no hidden code, full auditability.

## 🚀 Quick Start

### Simple Task: Profile One Function

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- In your code:
Profiler.Begin("MyFunction")
-- Your expensive code here
Profiler.End("MyFunction")
```

**That's it!** The profiler shows timing, memory, and visual bars.

### Medium Task: Profile Multiple Functions

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Tick context (CreateMove callback)
local function onCreateMove(cmd)
    Profiler.SetContext("tick")  -- Switch to tick context

    Profiler.Begin("Aimbot")
    -- Aimbot logic
    Profiler.End("Aimbot")

    Profiler.Begin("Movement")
    -- Movement logic
    Profiler.End("Movement")
end

-- Frame context (Draw callback)
local function onDraw()
    Profiler.SetContext("frame")  -- Switch to frame context
    Profiler.Draw()  -- Render profiler UI
end

callbacks.Register("CreateMove", "profiler_test", onCreateMove)
callbacks.Register("Draw", "profiler_draw", onDraw)
```

**Dual context profiling**: Separate tick work (game logic) from frame work (rendering) for accurate performance tracking.

### Advanced: Automatic Function Profiling

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)
Profiler.SetAutoHookEnabled(true)  -- Enable automatic function hooks

-- All your functions are now automatically profiled!
-- No manual Begin/End calls needed
```

**Automatic profiling** hooks all user functions and shows hierarchical call graphs, just like Roblox's microprofiler.

## 📖 Usage Patterns

### Pattern 1: Quick Performance Check (30 seconds)

**Use case:** "Is this function slow?"

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

-- Wrap the suspicious function
Profiler.Begin("SuspiciousFunction")
SuspiciousFunction()
Profiler.End("SuspiciousFunction")

-- Look at the profiler UI - if the bar is wide, it's slow!
```

### Pattern 2: Find Bottlenecks (5 minutes)

**Use case:** "Which part of my script is slow?"

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

function myScript()
    Profiler.Begin("Part1")
    -- First part
    Profiler.End("Part1")

    Profiler.Begin("Part2")
    -- Second part
    Profiler.End("Part2")

    Profiler.Begin("Part3")
    -- Third part
    Profiler.End("Part3")
end

-- The widest bar in the profiler is your bottleneck
```

### Pattern 3: Production Monitoring (Always On)

**Use case:** "Monitor performance during gameplay"

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)

callbacks.Register("CreateMove", "monitor", function(cmd)
    Profiler.SetContext("tick")

    Profiler.Begin("GameLogic")
    RunAllGameLogic()
    Profiler.End("GameLogic")
end)

callbacks.Register("Draw", "ui", function()
    Profiler.SetContext("frame")
    Profiler.Draw()
end)

-- Press P to pause/resume
-- Drag to pan, Q/E to zoom
```

### Pattern 4: Deep Analysis (Automatic Profiling)

**Use case:** "Show me everything that's running"

```lua
local Profiler = require("Profiler")
Profiler.SetVisible(true)
Profiler.SetAutoHookEnabled(true)  -- Hook all functions

-- Run your script normally
-- The profiler automatically shows:
--   • All function calls
--   • Call hierarchy (which function called what)
--   • Per-script breakdown
--   • Memory allocation per function

-- No manual Begin/End needed!
```

## 🔧 API Reference

### Core Functions

| Function           | Description                       | Example                       |
| ------------------ | --------------------------------- | ----------------------------- |
| `SetVisible(bool)` | Show/hide profiler UI             | `Profiler.SetVisible(true)`   |
| `Begin(name)`      | Start measuring                   | `Profiler.Begin("Aimbot")`    |
| `End(name)`        | Stop measuring                    | `Profiler.End("Aimbot")`      |
| `Draw()`           | Render UI (call in Draw callback) | `Profiler.Draw()`             |
| `SetContext(ctx)`  | Switch context ("tick"/"frame")   | `Profiler.SetContext("tick")` |
| `TogglePause()`    | Pause/resume recording            | `Profiler.TogglePause()`      |
| `Reset()`          | Clear all data                    | `Profiler.Reset()`            |

### Context Switching

The profiler has **two separate contexts** to accurately measure tick work vs frame work:

```lua
-- TICK context: Game logic, physics, aimbot, etc.
callbacks.Register("CreateMove", "logic", function(cmd)
    Profiler.SetContext("tick")  -- Record to tick timeline

    Profiler.Begin("MyGameLogic")
    -- This work appears in the TICK ruler
    Profiler.End("MyGameLogic")
end)

-- FRAME context: Rendering, UI drawing, ESP, etc.
callbacks.Register("Draw", "render", function()
    Profiler.SetContext("frame")  -- Record to frame timeline

    Profiler.Begin("MyRendering")
    -- This work appears in the FRAME ruler
    Profiler.End("MyRendering")

    Profiler.Draw()  -- Always render profiler in Draw
end)
```

**Why contexts matter:**

- Ticks run at 66 Hz (game tick rate)
- Frames run at your FPS (60-300 Hz)
- Mixing them shows inaccurate performance data
- Separate contexts = accurate ruler boundaries

### Configuration

```lua
Profiler.Setup({
    visible = true,
    smoothingSpeed = 2.5,        -- Bar animation speed (1-50)
    smoothingDecay = 1.5,        -- Peak decay speed (1-50)
    textUpdateInterval = 20,     -- Text refresh rate (frames)
    systemMemoryMode = "system", -- "system" or "components"
})
```

### Advanced Features

```lua
-- Automatic function hooking
Profiler.SetAutoHookEnabled(true)   -- Enable microprofiler mode
Profiler.IsAutoHookEnabled()         -- Check status

-- Pause/resume
Profiler.TogglePause()               -- Toggle pause
Profiler.IsPaused()                  -- Check if paused

-- Camera control
Profiler.ResetCamera()               -- Reset pan/zoom
Profiler.SetZoom(2.0)                -- Set zoom level
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

```
Profiler/
├── Main.lua              # Entry point, public API
├── Shared.lua            # Shared runtime data
├── microprofiler.lua     # Automatic function hooking, context management
├── profiler.lua          # Core profiling logic
├── ui_body_simple.lua    # Visual timeline with rulers
├── ui_top.lua            # Top bar UI
├── ui_warning.lua        # Timing server warnings
├── timing.lua            # High-precision timing (uses timing server if available)
├── config.lua            # Default settings
└── globals.lua           # Legacy compatibility

timing_server/           # Optional nanosecond timing server
├── src/main.rs          # Rust source code
├── Cargo.toml           # Rust dependencies
└── target/release/      # Compiled binaries
```

### Building from Source

**Profiler library:**

```bash
# Requirements: Node.js
npm install              # Install bundler dependencies
node bundle.js           # Bundle Profiler.lua
# Output: Profiler.lua (auto-copied to %LOCALAPPDATA%\lua\)
```

**Timing server:**

```bash
# Requirements: Rust toolchain (rustup.rs)
cd timing_server
cargo build --release
# Output: target/release/timing_server.exe
```

**Everything is open source** - audit the code yourself before use.

### How It Works

1. **Timing**: Uses timing server (nanosecond precision) or falls back to `os.clock()` (~10ms precision)
2. **Context Switching**: `SetContext("tick"/"frame")` records callback entry timestamps for accurate ruler boundaries
3. **Boundary Tracking**: Rulers show actual callback invocations using `globals.TickCount()` and `globals.FrameCount()`
4. **Dual Timelines**: Separate tick/frame timelines prevent mixing 66 Hz game logic with variable FPS rendering
5. **Virtual Board**: 2000x2000px coordinate system allows infinite zoom/pan with pixel-perfect alignment

### Performance Impact

| Mode                  | Overhead                    | Use Case              |
| --------------------- | --------------------------- | --------------------- |
| **Manual profiling**  | ~1-5 μs per Begin/End       | Production monitoring |
| **Auto-hook enabled** | ~10-50 μs per function call | Deep debugging        |
| **UI rendering**      | ~100-500 μs per frame       | Always-on, optimized  |

Profiler uses **zero-allocation paths** in hot code and defers cleanup to cooldown periods.

### Precision Comparison

| Timing Source   | Precision        | Profiler Behavior         |
| --------------- | ---------------- | ------------------------- |
| `timing_server` | **1 nanosecond** | Microsecond-accurate bars |
| `os.clock()`    | ~10 milliseconds | Works but less detailed   |

**Recommendation**: Run timing server for accurate profiling, use `os.clock()` for quick checks.

---

## 📚 Examples in Repo

- **`examples/example.lua`**: Basic manual profiling
- **`examples/fast_players_profile.lua`**: Real-world module profiling with dual contexts
- **`examples/simple_test.lua`**: Ultra-aggressive test (50-100ms functions)

## 🐛 Troubleshooting

**"Profiler shows nothing"**

- Add `Profiler.Begin()` / `Profiler.End()` around your code
- Check that `Profiler.SetVisible(true)` is called
- Ensure `Profiler.Draw()` is in your Draw callback

**"Timing seems wrong"**

- Run `timing_server.exe` for microsecond precision
- Verify `Profiler.SetContext("tick")` is in CreateMove
- Verify `Profiler.SetContext("frame")` is in Draw

**"Duplicate registration error"**

- Profiler auto-unregisters on reload (fixed in latest version)

**"Bars too small to see"**

- Press `Q` to zoom in
- Check if functions actually take measurable time (>1μs)

---

**Made with passion by titaniummachine1**

**Repository:** [github.com/titaniummachine1/Lmaobox_Profiler](https://github.com/titaniummachine1/Lmaobox_Profiler)  
**License:** MIT - Free to use, modify, and distribute
