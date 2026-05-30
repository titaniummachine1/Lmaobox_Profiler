# Archived: Rust timing_server

Replaced by [`timing_collector/`](../timing_collector/) (Go).

The Rust binary only provided `/now`, `/start`, and `/stop`. The Go collector adds session management, tick/frame boundaries, span collection, and flame graph export.

To build the old server for reference:

```bash
cd timing_server
cargo build --release
```
