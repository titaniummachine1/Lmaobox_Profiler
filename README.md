# Lmaobox Profiler

Drop-in Lua library + one Windows program. **Lua never measures time** — it only tells the collector when things start/stop. **`timing_collector.exe`** records nanoseconds and writes the flame graph.

---

## What you need (two files)

| File                       | Where                                                                 |
| -------------------------- | --------------------------------------------------------------------- |
| **`timing_collector.exe`** | `timing_collector\run\` — **double-click** and leave the window open. |
| **`Profiler.lua`**         | `%LOCALAPPDATA%\lua\Profiler.lua`                                     |

Download both from [GitHub Releases](https://github.com/titaniummachine1/Lmaobox_Profiler/releases) or build from this repo (below).

---

## First test (copy-paste path)

1. **Double-click** `timing_collector\run\timing_collector.exe`
   - Window should stay open and show `http://127.0.0.1:9876`
   - If it exits immediately, something else owns port 9876 — close that program and double-click again (the exe tries to free the port on Windows).

2. **Deploy Lua** (developers from repo root):

   ```bash
   npm install
   npm run bundle-deploy
   ```

   This writes `Profiler.lua` to `%LOCALAPPDATA%\lua\`.

3. **In TF2 (Lmaobox console)**:

   ```text
   lua_load simple_test
   ```

4. **Success** looks like:

   ```text
   [Profiler] OK flame_graphs/simple_test_<id>/tick.speedscope.json
   ```

5. **View the graph**
   - Your browser should open **http://127.0.0.1:9876/** automatically after export.
   - **Live** panel updates **while the script stays loaded** (open Live first, then `lua_load live_demo`).
   - **Saved sessions** → click one for an **inferno SVG** flame graph (same renderer as `cargo flamegraph`).
   - **Open in speedscope.app** link for timeline / Left Heavy (same data, deeper view).

Files on disk: `flame_graphs\<session_id>\tick.svg` (classic) and `tick.speedscope.json` (timeline).

---

## Profile while you play

```text
lua_load multi_tick_test
```

Play for a few seconds, then **unload** the script. Same `flame_graphs\...` folder; timeline includes many ticks (sampled ~1/sec so TF2 does not freeze from HTTP).

---

## Use in your own script

```lua
package.loaded["Profiler"] = nil  -- optional: fresh load while developing
local Profiler = require("Profiler")

Profiler.BindScript("my_cheat")   -- folder name under flame_graphs/
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
    print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
    return
end

callbacks.Register("CreateMove", "my_cheat_prof", function()
    Profiler.BeginTick()
    Profiler.Begin("fakelag")
    -- your code
    Profiler.End("fakelag")
    Profiler.EndTick()
end)

callbacks.Register("Unload", "my_cheat_prof", function()
    local ok, sessionId = Profiler.EndSession()
    if ok then
        print("[Profiler] OK flame_graphs/" .. sessionId .. "/tick.speedscope.json")
    else
        print("[Profiler] FAILED: " .. tostring(sessionId))
    end
end)
```

**Rules**

- Call **`Begin` / `End`** inside an active **`BeginTick`/`EndTick`** (CreateMove) or **`BeginFrame`/`EndFrame`** (Draw).
- The string in **`Begin("name")`** is exactly what appears in the flame graph.
- **`End(name)`** does not need to match; nesting is stack order.
- Do **not** call `callbacks.Unregister` from your script (Lmaobox policy — can crash). Use a `package.loaded` guard if you need “load once”.
- Do **not** profile every tick with many spans unless you accept heavy `http.Get` load — sample or keep spans few (see `multi_tick_test.lua`).

---

## API

| Function                      | Purpose                                          |
| ----------------------------- | ------------------------------------------------ |
| `BindScript(name)`            | Session folder name (call before `BeginSession`) |
| `BeginSession()`              | `true` / `false` — collector must be running     |
| `EndSession()`                | Returns `ok, sessionIdOrError`                   |
| `BeginTick()` / `EndTick()`   | CreateMove boundary                              |
| `BeginFrame()` / `EndFrame()` | Draw boundary                                    |
| `Begin(name)` / `End()`       | Span (collector times it)                        |
| `GetLastError()`              | Message after failed begin/end                   |
| `GetLastExportSessionID()`    | Folder name after successful `EndSession`        |
| `SetEnabled(false)`           | No-op profiler (no HTTP)                         |

---

## When flame graphs are written

- You call **`EndSession()`** (e.g. on **Unload**)
- **3 seconds** after the last span/tick/frame activity (idle export)
- A new script starts a session (ends the previous one)

If there is no data, nothing useful is written and Lua prints **`[Profiler] FAILED: ...`**.

---

## Examples (after `npm run bundle-deploy`)

| Script                    | What it does                 |
| ------------------------- | ---------------------------- |
| **`simple_test.lua`**     | One tick, instant smoke test (no Live) |
| **`live_demo.lua`**       | **Use for Live** — nested spans, ~6 samples/sec |
| **`multi_tick_test.lua`** | Many ticks; nested tree; unload to export |
| **`example.lua`**         | One tick with nested spans   |
| **`proof.lua`**           | Checks collector responds    |

---

## Build from source (developers)

```bash
# Lua bundle → %LOCALAPPDATA%\lua\Profiler.lua
npm install
npm run bundle-deploy

# Windows collector (Go + hidden Rust inferno helper for SVG)
timing_collector\build.bat
```

Requires [Go](https://go.dev/dl/). For **cargo-flamegraph-quality** SVG, install [Rust](https://rustup.rs/) before `build.bat` — it also builds `flamegraph_gen.exe` into `run\` (used automatically; you only double-click `timing_collector.exe`).

Repo layout: `Profiler/` → `Profiler.lua`; `timing_collector/run/` (exes); `timing_collector/cmd/` (Go); `timing_collector/flamegraph_gen/` (Rust); `examples/`.

---

## Troubleshooting

| Symptom                                           | Fix                                                                         |
| ------------------------------------------------- | --------------------------------------------------------------------------- |
| `[Profiler] FAILED: timing_collector not running` | Double-click `timing_collector\run\timing_collector.exe`                    |
| `[Profiler] FAILED: outdated`                     | Run `timing_collector\build.bat`                                            |
| Port 9876 in use                                  | Close old collector; exe frees port on start (Windows)                      |
| speedscope empty / broken                         | Open **`tick.speedscope.json`**, not `.folded.txt`                          |
| Game freeze with profiling                        | Fewer spans per tick; use `multi_tick_test` sampling, not 66 full ticks/sec |
| `Already loaded`                                  | Normal — restart game or use another callback tag                           |

---

## License

MIT
