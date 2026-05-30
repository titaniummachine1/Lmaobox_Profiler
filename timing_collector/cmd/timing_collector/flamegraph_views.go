package main

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
)

const (
	flameViewMerged = iota
	flameViewAverage
	flameViewLast
)

var flameViewFiles = []string{"tick.svg", "tick_avg.svg", "tick_last.svg"}

func flameViewTitles(script string, nTicks int) []string {
	base := script
	if base == "" {
		base = "tick"
	}
	merged := base
	if nTicks > 0 {
		merged = fmt.Sprintf("%s — %d ticks (merged)", base, nTicks)
	}
	return []string{
		merged,
		base + " — average tick",
		base + " — last tick",
	}
}

func stackKey(stack []string, name string) string {
	if len(stack) == 0 {
		return name
	}
	return strings.Join(stack, ";")
}

func spanDurationNs(s completedSpan) int64 {
	return spanDurationNsFromBounds(s.startNs, s.endNs)
}

func spanFromStackKey(key string, dur int64) completedSpan {
	if dur < 1 {
		dur = 1
	}
	parts := strings.Split(key, ";")
	name := key
	if len(parts) > 0 {
		name = parts[len(parts)-1]
	}
	return completedSpan{
		name:    name,
		ctx:     "tick",
		startNs: 0,
		endNs:   dur,
		stack:   parts,
	}
}

// sumLeafDurationsByKey adds self-time per stack path across ticks (each batch is leaf-only).
func sumLeafDurationsByKey(batches [][]completedSpan) map[string]int64 {
	byKey := map[string]int64{}
	for _, batch := range batches {
		for _, s := range batch {
			key := stackKey(s.stack, s.name)
			d := spanDurationNs(s)
			if d <= 0 {
				continue
			}
			byKey[key] += d
		}
	}
	return byKey
}

func spansFromDurationMap(byKey map[string]int64) []completedSpan {
	if len(byKey) == 0 {
		return nil
	}
	keys := make([]string, 0, len(byKey))
	for k := range byKey {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]completedSpan, 0, len(keys))
	for _, key := range keys {
		out = append(out, spanFromStackKey(key, byKey[key]))
	}
	return out
}

// mergedSpansFromTicks totals self-time per stack across all tick batches (session flame graph).
func mergedSpansFromTicks(batches [][]completedSpan) []completedSpan {
	return spansFromDurationMap(sumLeafDurationsByKey(batches))
}

func averageSpansFromTicks(batches [][]completedSpan) []completedSpan {
	if len(batches) == 0 {
		return nil
	}
	type acc struct {
		sum int64
		n   int64
	}
	byKey := map[string]acc{}
	for _, batch := range batches {
		for _, s := range batch {
			key := stackKey(s.stack, s.name)
			d := spanDurationNs(s)
			if d <= 0 {
				continue
			}
			a := byKey[key]
			a.sum += d
			a.n++
			byKey[key] = a
		}
	}
	if len(byKey) == 0 {
		return nil
	}
	keys := make([]string, 0, len(byKey))
	for k := range byKey {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]completedSpan, 0, len(keys))
	for _, key := range keys {
		a := byKey[key]
		if a.n == 0 {
			continue
		}
		avg := a.sum / a.n
		out = append(out, spanFromStackKey(key, avg))
	}
	return out
}

func lastTickSpansFromBatches(batches [][]completedSpan) []completedSpan {
	if len(batches) == 0 {
		return nil
	}
	last := batches[len(batches)-1]
	return append([]completedSpan(nil), last...)
}

func currentTickSpansLocked(now int64) []completedSpan {
	var out []completedSpan
	for _, id := range collectSpanIDs(state.spans) {
		rec := state.spans[id]
		if rec == nil || rec.ctx != "tick" {
			continue
		}
		end := rec.endNs
		if !rec.closed || end == 0 {
			end = now
		}
		end = normalizeSpanEnd(rec.startNs, end)
		out = append(out, completedSpan{
			name:    rec.name,
			ctx:     rec.ctx,
			startNs: rec.startNs,
			endNs:   end,
			stack:   buildStackNames(rec, state.spans),
		})
	}
	return spansForFlamegraph(out)
}

func mergedSpansForLiveLocked(now int64) []completedSpan {
	batches := append([][]completedSpan(nil), state.tickSpanBatches...)
	if state.tickOpen {
		cur := currentTickSpansLocked(now)
		if len(cur) > 0 {
			batches = append(batches, cur)
		}
	}
	return mergedSpansFromTicks(batches)
}

func tickCountForFlameTitles() int {
	n := len(state.tickSpanBatches)
	if state.tickOpen {
		n++
	}
	return n
}

func liveFlameSpansLocked(now int64, view int) ([]completedSpan, string) {
	script := state.scriptName
	n := tickCountForFlameTitles()
	titles := flameViewTitles(script, len(state.tickSpanBatches))

	switch view {
	case flameViewAverage:
		sp := averageSpansFromTicks(state.tickSpanBatches)
		if len(sp) == 0 {
			return nil, ""
		}
		return sp, titles[1]
	case flameViewLast:
		if len(lastTickLiveSpans) > 0 {
			return append([]completedSpan(nil), lastTickLiveSpans...), titles[2]
		}
		sp := lastTickSpansFromBatches(state.tickSpanBatches)
		if len(sp) == 0 {
			return nil, ""
		}
		return sp, titles[2]
	default:
		sp := mergedSpansForLiveLocked(now)
		if len(sp) == 0 {
			return nil, ""
		}
		return sp, flameViewTitles(script, n)[0]
	}
}

func sessionFlameFile(view int) string {
	if view < 0 || view >= len(flameViewFiles) {
		return flameViewFiles[0]
	}
	return flameViewFiles[view]
}

func writeFlamegraphViews(dir string, batches [][]completedSpan, scriptName string) error {
	n := len(batches)
	titles := flameViewTitles(scriptName, n)
	views := []struct {
		file              string
		spans             []completedSpan
		title             string
		summedAcrossTicks bool
	}{
		{flameViewFiles[0], mergedSpansFromTicks(batches), titles[0], true},
		{flameViewFiles[1], averageSpansFromTicks(batches), titles[1], false},
		{flameViewFiles[2], lastTickSpansFromBatches(batches), titles[2], false},
	}
	var wrote bool
	for _, v := range views {
		if len(v.spans) == 0 {
			continue
		}
		ctx := strings.TrimSuffix(v.file, ".svg")
		if err := writeFlamegraphWithTitle(dir, ctx, v.spans, scriptName, v.title, v.summedAcrossTicks); err != nil {
			return err
		}
		wrote = true
	}
	if !wrote {
		return fmt.Errorf("tick: no flame graph spans")
	}
	return nil
}

func parseFlameViewQuery(r *http.Request) int {
	v := strings.TrimSpace(r.URL.Query().Get("profile"))
	if v == "" {
		v = strings.TrimSpace(r.URL.Query().Get("view"))
	}
	switch v {
	case "1", "average", "avg":
		return flameViewAverage
	case "2", "last":
		return flameViewLast
	default:
		if i, err := strconv.Atoi(v); err == nil && i >= 0 && i < len(flameViewFiles) {
			return i
		}
		return flameViewMerged
	}
}
