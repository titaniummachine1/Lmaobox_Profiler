# 🎯 Profiler - Performance Monitoring for Lmaobox

![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

[![Download Latest](https://img.shields.io/badge/Download%20Latest-Profiler.lua-brightgreen?style=for-the-badge&logo=download)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

[![Download Timing Server](https://img.shields.io/badge/Download-Timing%20Server-blue?style=for-the-badge&logo=download)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/download/v1.3.0/timing_server.exe)

A lightweight, microsecond-precision performance profiler that shows exactly what's consuming your CPU and memory. Features dual-context tick/frame profiling, automatic function hooking, and a visual timeline with accurate ruler boundaries.

> **Optional:** Download the timing server for microsecond precision. The profiler works without it but uses lower-precision timing (~10ms). _Don't trust random executables? See compilation instructions below._

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

**Note:** Function names are automatically simplified - "Navigation.CanNavigate.GoalCheck" shows as "GoalCheck"

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

**Automatic Nesting:** Work started within another work automatically becomes its child. No need for manual hierarchical names!

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

**Text Layout:** Names are prioritized, time shows on right if it fits, memory below if space allows.

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

**Smart Text:** Short blocks show ".." truncation, names always visible when possible.

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

-- Press P to pause/resume (data preserved on unpause!)
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

### Advanced Features

```lua
-- Pause/resume recording
Profiler.TogglePause()               -- Press P or call this
Profiler.IsPaused()                  -- Check pause state

-- Camera controls
Profiler.ResetCamera()               -- Reset pan/zoom to default
Profiler.SetZoom(2.0)                -- Set specific zoom level

-- Clear all data
Profiler.Reset()                     -- Wipe timeline, start fresh
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

## 🎨 What You See

### Timeline View

- **TICK ruler** (top): Shows game ticks at 66 Hz with work bars
- **FRAME ruler** (bottom): Shows rendered frames with work bars
- **Colored bars**: Your profiled work (Begin/End calls)
- **Ruler lines**: Vertical lines marking tick/frame boundaries
- **Time scale**: Horizontal spacing (50,000 pixels per second = 1ms = 50px)
- **Zoom**: Use Q/E to zoom in/out, drag to pan

### What the Bars Mean

- **Wide bars**: Slow code (taking more time)
- **Narrow bars**: Fast code
- **Gaps**: Code not running (frame drops, skipped ticks, etc.)
- **Overlapping**: Multiple things profiled in same tick/frame

## 📝 Real Example

Check `examples/fast_players_profile.lua` for a complete real-world example:

```lua
local Profiler = require("Profiler")
local FastPlayers = require("fast_players")

Profiler.SetVisible(true)

callbacks.Register("CreateMove", "profiler_tick", function(cmd)
    Profiler.SetContext("tick")  -- Switch to tick timeline

    Profiler.Begin("FastPlayers.Total")

    Profiler.Begin("FastPlayers.Update")
    FastPlayers.Update()
    Profiler.End("FastPlayers.Update")

    Profiler.Begin("FastPlayers.GetAll")
    local allPlayers = FastPlayers.GetAll()
    Profiler.End("FastPlayers.GetAll")

    -- More profiled work...

    Profiler.End("FastPlayers.Total")
end)

callbacks.Register("Draw", "profiler_frame", function()
    Profiler.SetContext("frame")  -- Switch to frame timeline
    Profiler.Draw()  -- Render profiler UI
end)
```

**Key points:**

- `SetContext("tick")` in CreateMove → records to TICK timeline
- `SetContext("frame")` in Draw → records to FRAME timeline
- `Draw()` renders the profiler UI
- Nested Begin/End calls show hierarchy

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

**"Data disappears on unpause"**

- Fixed! Data is now preserved when unpausing. No more crashes or data loss.

**"Bars too small to see"**

- Press `Q` to zoom in
- Check if functions actually take measurable time (>1μs)

---

**Made with passion by titaniummachine1**

**Repository:** [github.com/titaniummachine1/Lmaobox_Profiler](https://github.com/titaniummachine1/Lmaobox_Profiler)  
**License:** MIT - Free to use, modify, and distribute
