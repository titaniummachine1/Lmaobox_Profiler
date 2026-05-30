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

func totalMergedNsFromBatches(batches [][]completedSpan) int64 {
	var total int64
	for _, v := range sumLeafDurationsByKey(batches) {
		total += v
	}
	return total
}

func formatFlameDuration(ns int64) string {
	if ns < 1_000_000 {
		return fmt.Sprintf("%.0f ns", float64(ns))
	}
	if ns < 1_000_000_000 {
		return fmt.Sprintf("%.1f ms", float64(ns)/1e6)
	}
	return fmt.Sprintf("%.2f s", float64(ns)/1e9)
}

func flameMergedTitle(script string, batches [][]completedSpan, perTick []speedscopeEventedProfile) string {
	base := script
	if base == "" {
		base = "tick"
	}
	n := len(batches)
	if len(perTick) > 0 {
		n = len(perTick)
	}
	if n == 0 {
		return base
	}
	if events, _, _, tickStarts, err := mergeTickProfiles(perTick); err == nil && len(events) >= 2 {
		dur := events[len(events)-1].At - events[0].At
		if len(tickStarts) > 0 {
			n = len(tickStarts)
		}
		title := fmt.Sprintf("%s — %d ticks · %s timeline", base, n, formatFlameDuration(dur))
		if n > 1 && dur > 0 {
			title += fmt.Sprintf(" (~%s/tick)", formatFlameDuration(dur/int64(n)))
		}
		return title
	}
	total := totalMergedNsFromBatches(batches)
	title := fmt.Sprintf("%s — %d ticks · %s total", base, n, formatFlameDuration(total))
	if n > 1 && total > 0 {
		title += fmt.Sprintf(" (~%s/tick)", formatFlameDuration(total/int64(n)))
	}
	return title
}

func flameViewTitles(script string, batches [][]completedSpan, perTick []speedscopeEventedProfile) []string {
	base := script
	if base == "" {
		base = "tick"
	}
	return []string{
		flameMergedTitle(script, batches, perTick),
		base + " — average tick",
		base + " — last tick",
	}
}

func liveTickProfilesForTimelineLocked() []speedscopeEventedProfile {
	out := append([]speedscopeEventedProfile(nil), state.tickProfiles...)
	if !state.tickOpen {
		return out
	}
	start := state.tickEventsStart
	end := len(state.tickEvents)
	if end <= start {
		return out
	}
	chunk := append([]speedscopeEvent(nil), state.tickEvents[start:end]...)
	chunk = enforceMonotonicEventTimes(rebaseEvents(chunk))
	if len(chunk) < 2 {
		return out
	}
	out = append(out, speedscopeEventedProfile{
		Type:       "evented",
		Name:       "tick (open)",
		Unit:       "nanoseconds",
		StartValue: chunk[0].At,
		EndValue:   chunk[len(chunk)-1].At,
		Events:     chunk,
	})
	return out
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
	batches := state.tickSpanBatches
	perTick := liveTickProfilesForTimelineLocked()
	titles := flameViewTitles(script, batches, perTick)

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
		return sp, titles[0]
	}
}

func sessionFlameFile(view int) string {
	if view < 0 || view >= len(flameViewFiles) {
		return flameViewFiles[0]
	}
	return flameViewFiles[view]
}

func writeFlamegraphViews(dir string, batches [][]completedSpan, perTick []speedscopeEventedProfile, frameMap map[string]int, scriptName string) error {
	titles := flameViewTitles(scriptName, batches, perTick)
	var wrote bool

	if len(perTick) > 0 && len(frameMap) > 0 {
		if err := writeTimelineFlamegraph(dir, "tick", perTick, frameMap, titles[0]); err != nil {
			return err
		}
		wrote = true
	} else if sp := mergedSpansFromTicks(batches); len(sp) > 0 {
		if err := writeFlamegraphWithTitle(dir, "tick", sp, scriptName, titles[0], true); err != nil {
			return err
		}
		wrote = true
	}

	if sp := averageSpansFromTicks(batches); len(sp) > 0 {
		if err := writeFlamegraphWithTitle(dir, "tick_avg", sp, scriptName, titles[1], false); err != nil {
			return err
		}
		wrote = true
	}
	if sp := lastTickSpansFromBatches(batches); len(sp) > 0 {
		if err := writeFlamegraphWithTitle(dir, "tick_last", sp, scriptName, titles[2], false); err != nil {
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
