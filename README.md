# Lmaobox Profiler

Drop-in Lua library + one Windows program. **Lua never measures time** — it only tells the collector when things start/stop. **`timing_collector.exe`** records nanoseconds and serves graphs at **http://127.0.0.1:9876/**.

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
   - If it exits immediately, something else owns port **9876** — close that program and double-click again (the exe tries to free the port on Windows).

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
   - Browser opens **http://127.0.0.1:9876/** after export (or open it yourself).
   - **Saved sessions** → click one → **Flame graph** or **Speedscope**.
   - **View** dropdown: **ALL ticks (merged)** · **Average tick** · **Last tick** (same choices for flame and timeline).

Files on disk: `tick.svg`, `tick_avg.svg`, `tick_last.svg`, and `tick.speedscope.json` (three profiles inside).

---

## Live profiling (while script stays loaded)

1. Open **http://127.0.0.1:9876/** → click **Live** (top-left).
2. In TF2: `lua_load multi_tick_test` or `lua_load live_demo` — **keep the script loaded** while you play.
3. The **sidebar** (bars + event log) updates automatically every ~400 ms.
4. **Flame graph** and **Speedscope** do **not** auto-refresh (so zoom/pan is not reset). When the button shows **Update graph \***, click it to load new data.
5. Use **View** for merged / average / last tick — applies to both flame (top-down SVG) and Speedscope timeline.

`multi_tick_test` samples every 22 game ticks and prints `sample N` in console when a tick is captured.

---

## Profile while you play (saved session)

```text
lua_load multi_tick_test
```

Play for a few seconds, then **unload** the script. Session folder: `flame_graphs\<session_id>\`. Same **View** options in the web UI.

---

## Use in your own script

```lua
package.loaded["Profiler"] = nil  -- optional: fresh load while developing
local Profiler = require("Profiler")

Profiler.BindScript("my_cheat")
Profiler.SetEnabled(true)

if not Profiler.BeginSession() then
    print("[Profiler] FAILED: " .. tostring(Profiler.GetLastError()))
    return
end

-- Re-register safely on lua_load (Lmaobox: Unregister before Register at load time only)
callbacks.Unregister("CreateMove", "my_cheat_prof")
callbacks.Register("CreateMove", "my_cheat_prof", function()
    Profiler.BeginTick()
    Profiler.Begin("fakelag")
    -- your code
    Profiler.End("fakelag")
    Profiler.EndTick()
end)

callbacks.Unregister("Unload", "my_cheat_prof")
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
- **`callbacks.Unregister` only at script load** (before `Register`), not inside CreateMove/Unload handlers — Lmaobox policy (luacheck enforces this).
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

| Script                    | What it does                                      |
| ------------------------- | ------------------------------------------------- |
| **`simple_test.lua`**     | One tick, instant smoke test (no Live)            |
| **`live_demo.lua`**       | **Use for Live** — nested spans, frequent samples |
| **`multi_tick_test.lua`** | Many ticks; nested tree; unload to export         |
| **`proof.lua`**           | Checks collector responds                         |

---

## Build from source (developers)

```bash
npm install
npm run bundle-deploy

timing_collector\build.bat
```

Requires [Go](https://go.dev/dl/). For **top-down icicle SVG** (root on top), install [Rust](https://rustup.rs/) and run `build.bat` so **`flamegraph_gen.exe`** is copied next to `timing_collector.exe`. Without it, a built-in SVG renderer is used (also top-down).

Repo layout: `Profiler/` → `Profiler.lua`; `timing_collector/run/` (exes); `timing_collector/cmd/` (Go); `timing_collector/flamegraph_gen/` (Rust); `examples/`.

---

## Troubleshooting

| Symptom                                           | Fix                                                                                     |
| ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `[Profiler] FAILED: timing_collector not running` | Double-click `timing_collector\run\timing_collector.exe`                                |
| `[Profiler] FAILED: outdated`                     | Run `timing_collector\build.bat`                                                        |
| Port 9876 in use                                  | Close old collector; exe frees port on start (Windows)                                  |
| Speedscope scroll/zoom too fast                   | Rebuild (`build.bat` patches wheel sensitivity); **Ctrl+wheel** zooms, plain wheel pans |
| Speedscope shows wrong profile vs **View**        | Rebuild collector + hard-refresh browser; pick **View** then **Update graph** (Live)    |
| Timeline keeps resetting while zooming (Live)     | Expected if an old UI auto-refreshed — rebuild; only **Update graph \*** reloads graphs |
| Flame graph root at bottom instead of top         | Run `build.bat` (needs `flamegraph_gen.exe` with icicle / Straight mode)                |
| Game freeze with profiling                        | Fewer spans per tick; use sampling like `multi_tick_test`, not every tick               |
| SteamNetworkingSockets / DB messages in console   | Unrelated TF2/Lmaobox noise — ignore for profiler testing                               |
| `lua_load` again while testing Live               | OK — examples re-register callbacks at load; keep script loaded for Live                |

---

## License

MIT
