# timing_collector

Go HTTP collector for the Lmaobox Profiler Lua client. Stdlib only.

## Build

```bash
cd timing_collector
go build -o timing_collector.exe .
```

## Run

```bash
./timing_collector.exe
```

Listens on `http://127.0.0.1:9876`. Writes `flame_graphs/<session_id>/` next to the executable.

**Session lifecycle:** A session ends (and files are written) when:

- `GET /session/end` is called (Lua unload / `Profiler.EndSession()`)
- `GET /session/begin?script=...` starts a new script session (previous session is exported first)
- **No tick/frame/span requests for 3 seconds** after profiling has started — idle timeout

Idle timeout does **not** run for a session that only received `/session/begin` (e.g. script loaded but not in-game yet).

`GET /now` and `/session/begin` do **not** count as profiling activity.

If the window closes immediately, port 9876 is likely in use — run `run_collector.bat` to see the error, or stop the old Rust `timing_server.exe`.

- `tick.speedscope.json` / `frame.speedscope.json` — open at [speedscope.app](https://www.speedscope.app)
- `tick.folded.txt` / `frame.folded.txt` — Brendan Gregg folded format
- `session.meta.json` — script name and span counts

## HTTP API (all GET — Lmaobox `http.Get` only)

| Path             | Query                            | Response                          |
| ---------------- | -------------------------------- | --------------------------------- |
| `/now`           |                                  | nanoseconds since collector start |
| `/session/begin` | `script`                         | session id                        |
| `/session/end`   |                                  | `1`                               |
| `/tick/begin`    |                                  | `0` / `-1`                        |
| `/tick/end`      |                                  | `0` / `-1`                        |
| `/frame/begin`   |                                  | `0` / `-1`                        |
| `/frame/end`     |                                  | `0` / `-1`                        |
| `/span/start`    | `name`, `ctx`, optional `parent` | span id                           |
| `/span/end`      | `span_id`                        | duration ns                       |

## Lua usage

See repository `README.md` and `examples/example.lua`.
