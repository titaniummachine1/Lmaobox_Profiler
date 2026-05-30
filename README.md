# Lmaobox Profiler

Lua profiling library for [Lmaobox](https://lmaobox.net/lua/) that sends spans to a local **Go collector**. Flame graphs are written to disk (no in-game UI).

## Quick start

### 1. Build and run the collector

```bash
cd timing_collector
go build -o timing_collector.exe .
timing_collector.exe
```

Listens on `http://127.0.0.1:9876`. Output directory: `timing_collector/flame_graphs/<session_id>/` (next to the executable).

### 2. Build the Lua library

```bash
npm install
npm run bundle-deploy
```

Copies **`Profiler.lua`** (drop-in library for `%LOCALAPPDATA%\lua\`) and **`examples/*.lua`**.

Any script: `local Profiler = require("Profiler")` then talk to `timing_collector.exe` on port 9876. No extra Lua files to install.

If export fails, the game console prints `[Profiler] FAILED: …` and the collector writes **`session.error.txt`** only (no empty speedscope files).

**Automatic dev workflow** (same pattern as Cheater Detection):

- **On save** — install [Run on Save](https://marketplace.visualstudio.com/items?itemName=achilleshr.runonsave) (or emeraldwalk); saving any `.lua` runs `BundleAndDeploy.bat --no-collector`
- **On folder open** — task _Bundle on folder open_ runs once (allow in prompt)
- **Watch mode** — `npm run watch` rebundles when `Profiler/` or `examples/` changes
- **Ctrl+Shift+B** — full bundle + Go collector build

### 3. Instrument your script

```lua
local Profiler = require("Profiler")
Profiler.SetEnabled(true)

callbacks.Register("CreateMove", "my_tick", function(cmd)
    Profiler.BeginTick()
    Profiler.Begin("Aimbot")
    -- ...
    Profiler.End("Aimbot")
    Profiler.EndTick()
end)

callbacks.Register("Draw", "my_frame", function()
    Profiler.BeginFrame()
    Profiler.Begin("ESP")
    -- ...
    Profiler.End("ESP")
    Profiler.EndFrame()
end)
```

### 4. View results

Recommended test script: `lua_load test_flamegraphs` (see [`examples/test_flamegraphs.lua`](examples/test_flamegraphs.lua)).

After playing, unloading the script, or **3 seconds with no profiling traffic**, open:

- `*.speedscope.json` in [speedscope.app](https://www.speedscope.app)
- `*.folded.txt` with your preferred flame graph tool

## API

| Function                      | Description                                        |
| ----------------------------- | -------------------------------------------------- |
| `BeginTick()` / `EndTick()`   | Wrap CreateMove profiling (tick context)           |
| `BeginFrame()` / `EndFrame()` | Wrap Draw profiling (frame context)                |
| `Begin(name)` / `End(name)`   | Nested work spans inside active tick/frame         |
| `SetEnabled(bool)`            | Gate HTTP when collector is offline                |
| `BeginSession()`              | Optional; auto-runs on require when script changes |
| `EndSession()`                | Returns `ok, sessionIdOrError` — check `ok`        |
| `GetLastError()`              | Why `BeginSession` / `EndSession` failed           |
| `GetLastExportSessionID()`    | After success: folder name under `flame_graphs/`   |
| `IsCollectorAvailable()`      | Probe `/now`                                       |
| `GetSessionID()`              | Active session id (nil after EndSession)           |

## Session end

The Go collector exports `flame_graphs/` when:

- You call `Profiler.EndSession()` or unload the script
- A new script calls `require("Profiler")` (new session replaces the old one)
- **3 seconds** pass with no tick/frame/span traffic **after profiling has started** (idle does not run on `/session/begin` alone)

## Examples

Deploy with `npm run bundle-deploy`, `BundleAndDeploy.bat`, or `examples\deployexamples.bat` (all bundle first; `deployexamples` no longer copies examples only).

| Script                 | Purpose                                              |
| ---------------------- | ---------------------------------------------------- |
| `test_flamegraphs.lua` | Main test — banner, heavy spans, unload + idle hints |
| `simple_test.lua`      | Lighter load smoke test                              |
| `example.lua`          | Nested span demo                                     |
| `proof.lua`            | Check collector is running                           |

## Project layout

```
Profiler/           Lua sources (bundled to Profiler.lua)
timing_collector/   Go HTTP server + flame_graphs export
timing_server/      Archived Rust clock-only server
examples/           Sample scripts
bundle.js           luabundle entry: Profiler/Main.lua
```

## Legacy Rust server

The old `timing_server` (Rust) is archived. Use `timing_collector` instead.

## License

MIT
