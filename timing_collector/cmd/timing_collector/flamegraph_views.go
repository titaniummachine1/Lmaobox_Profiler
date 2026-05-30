package main

import (
	"fmt"
	"net/http"
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

func averageSpansFromTicks(batches [][]completedSpan) []completedSpan {
	if len(batches) == 0 {
		return nil
	}
	type acc struct {
		sum int64
		n   int64
	}
	byKey := map[string]acc{}
	var template []completedSpan
	for _, batch := range batches {
		leaves := spansForFlamegraph(batch)
		if len(leaves) > len(template) {
			template = leaves
		}
		for _, s := range leaves {
			key := stackKey(s.stack, s.name)
			d := s.endNs - s.startNs
			if d <= 0 {
				continue
			}
			a := byKey[key]
			a.sum += d
			a.n++
			byKey[key] = a
		}
	}
	if len(template) == 0 {
		return nil
	}
	out := make([]completedSpan, 0, len(template))
	for _, s := range template {
		key := stackKey(s.stack, s.name)
		a := byKey[key]
		if a.n == 0 {
			continue
		}
		avg := a.sum / a.n
		if avg < 1 {
			avg = 1
		}
		out = append(out, completedSpan{
			name:    s.name,
			ctx:     s.ctx,
			startNs: 0,
			endNs:   avg,
			stack:   append([]string(nil), s.stack...),
		})
	}
	return out
}

func lastTickSpansFromBatches(batches [][]completedSpan) []completedSpan {
	if len(batches) == 0 {
		return nil
	}
	return append([]completedSpan(nil), batches[len(batches)-1]...)
}

func liveFlameSpansLocked(now int64, view int) ([]completedSpan, string) {
	switch view {
	case flameViewAverage:
		sp := averageSpansFromTicks(state.tickSpanBatches)
		if len(sp) == 0 {
			return nil, ""
		}
		return sp, "Average tick"
	case flameViewLast:
		if len(lastTickLiveSpans) > 0 {
			return append([]completedSpan(nil), lastTickLiveSpans...), "Last tick"
		}
		sp := lastTickSpansFromBatches(state.tickSpanBatches)
		if len(sp) == 0 {
			return nil, ""
		}
		return sp, "Last tick"
	default:
		return collectLiveDisplaySpansLocked(now), liveFlameRootName()
	}
}

func sessionFlameFile(view int) string {
	if view < 0 || view >= len(flameViewFiles) {
		return flameViewFiles[0]
	}
	return flameViewFiles[view]
}

func writeFlamegraphViews(dir string, batches [][]completedSpan, allSpans []completedSpan, scriptName string) error {
	n := len(batches)
	titles := flameViewTitles(scriptName, n)
	views := []struct {
		file  string
		spans []completedSpan
		title string
	}{
		{flameViewFiles[0], allSpans, titles[0]},
		{flameViewFiles[1], averageSpansFromTicks(batches), titles[1]},
		{flameViewFiles[2], lastTickSpansFromBatches(batches), titles[2]},
	}
	var wrote bool
	for _, v := range views {
		if len(v.spans) == 0 {
			continue
		}
		ctx := strings.TrimSuffix(v.file, ".svg")
		if err := writeFlamegraphWithTitle(dir, ctx, v.spans, scriptName, v.title); err != nil {
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
