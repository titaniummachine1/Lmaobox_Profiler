![Visitors](https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fgithub.com%2Ftitaniummachine1%2FLmaobox_Profiler&label=Visitors&countColor=%23263759&style=plastic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/issues)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/Lmaobox_Profiler.svg)](https://github.com/titaniummachine1/Lmaobox_Profiler/stargazers)

# Lmaobox Profiler

## 🚀 Download

[![Download Latest](https://img.shields.io/github/downloads/titaniummachine1/Lmaobox_Profiler/total.svg?style=for-the-badge&logo=download&label=Download%20Latest)](https://github.com/titaniummachine1/Lmaobox_Profiler/releases/latest/download/Profiler.lua)

Click the badge above to instantly download the latest `Profiler.lua` release.

Copy `Profiler.lua` and (optionally) files from `examples/` to your `%localappdata%` folder.

---

## ⚡ Quick API Usage

```lua
local Profiler = require("Profiler")

-- Show the profiler overlay
Profiler.SetVisible(true)

-- Profile a system and its components
Profiler.StartSystem("my_system")
    Profiler.StartComponent("my_function")
    -- ... your code ...
    Profiler.EndComponent("my_function")
Profiler.EndSystem("my_system")

-- Or profile a standalone component (auto-grouped as 'misc')
Profiler.StartComponent("standalone_task")
-- ... your code ...
Profiler.EndComponent("standalone_task")

-- Draw the profiler overlay (in your Draw callback)
Profiler.Draw()
```

---

# Profiler Library

A high-performance Lua profiler library for monitoring, analyzing, and optimizing code performance. Built with automatic bundling and deployment for seamless development workflow.

## Features

- 🚀 **Real-time Performance Monitoring** - Track function execution times and call frequencies
- 📊 **Detailed Analytics** - Memory usage, CPU time, and performance bottleneck detection
- 🔄 **Auto-bundling** - Automatic compilation and deployment on file save
- ⚡ **Lightweight** - Minimal overhead for production use
- 🛠️ **Easy Integration** - Simple API for quick setup

## Quick Start

### Auto-Bundle on Save

The repository is configured for automatic bundling when you save files:

- **Bundle only**: Run `Bundle.bat` or `npm run build`
- **Bundle + Deploy**: Run `BundleAndDeploy.bat` or `npm run deploy`

### Manual Commands

```bash
# Build the profiler library
npm run build

# Build and deploy to %localappdata%
npm run deploy
```

## Contact

[Contact me on Telegram](https://t.me/TerminatorMachine) if you have questions or need support.

## License

MIT License - feel free to use and modify!
