package main

// All span timestamps and durations come from timing_collector (Go monotonic clock).
// Lua never supplies trusted duration; /span/report ignores client dur_ns.

const minSpanDurationNs int64 = 1

func spanDurationNsFromBounds(startNs, endNs int64) int64 {
	d := endNs - startNs
	if d < minSpanDurationNs {
		return minSpanDurationNs
	}
	return d
}

func normalizeSpanEnd(startNs, endNs int64) int64 {
	if endNs <= startNs {
		return startNs + minSpanDurationNs
	}
	return endNs
}
