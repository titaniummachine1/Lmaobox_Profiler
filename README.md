# Lmaobox Profiler

Drop-in Lua library + one Windows program. **Lua never measures time** — it only tells the collector when things start/stop. **`timing_collector.exe`** records nanoseconds and writes the flame graph.

---

## What you need (two files)

| File                       | Where                                                                              |
| -------------------------- | ---------------------------------------------------------------------------------- |
| **`timing_collector.exe`** | Any folder (e.g. `timing_collector\`). **Double-click** and leave the window open. |
| **`Profiler.lua`**         | `%LOCALAPPDATA%\lua\Profiler.lua`                                                  |

Download both from [GitHub Releases](https://github.com/titaniummachine1/Lmaobox_Profiler/releases) or build from this repo (below).

---

## First test (copy-paste path)

1. **Double-click** `timing_collector\timing_collector.exe`
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

5. **Open the graph**
   - Path (next to the exe): `timing_collector\flame_graphs\<session_id>\tick.speedscope.json`
   - Drag that file into **https://www.speedscope.app**
   - Use **Left Heavy** to see what cost the most; **Time Order** for when things ran.

**Do not** open `tick.folded.txt` in speedscope — use **`.speedscope.json` only**.

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
| **`simple_test.lua`**     | One tick, instant smoke test |
| **`multi_tick_test.lua`** | Many ticks; unload to export |
| **`example.lua`**         | One tick with nested spans   |
| **`proof.lua`**           | Checks collector responds    |

---

## Build from source (developers)

```bash
# Lua bundle → %LOCALAPPDATA%\lua\Profiler.lua
npm install
npm run bundle-deploy

# Windows collector (double-clickable)
cd timing_collector
go build -o timing_collector.exe .
```

Repo layout: `Profiler/` (sources) → bundled to `Profiler.lua`; `timing_collector/` (Go); `examples/` (samples). `timing_server/` is archived Rust — do not use.

---

## Troubleshooting

| Symptom                                           | Fix                                                                         |
| ------------------------------------------------- | --------------------------------------------------------------------------- |
| `[Profiler] FAILED: timing_collector not running` | Double-click `timing_collector.exe`, keep window open                       |
| `[Profiler] FAILED: outdated`                     | Rebuild: `cd timing_collector && go build -o timing_collector.exe .`        |
| Port 9876 in use                                  | Close old collector; exe frees port on start (Windows)                      |
| speedscope empty / broken                         | Open **`tick.speedscope.json`**, not `.folded.txt`                          |
| Game freeze with profiling                        | Fewer spans per tick; use `multi_tick_test` sampling, not 66 full ticks/sec |
| `Already loaded`                                  | Normal — restart game or use another callback tag                           |

---

## License

MIT
