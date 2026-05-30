package main

import (
	"fmt"
	"strings"
	"time"
)

const maxLiveEvents = 120

type liveEvent struct {
	At   string `json:"at"`
	Kind string `json:"kind"`
	Text string `json:"text"`
}

var (
	liveEvents        []liveEvent
	liveGraphRev      uint64
	lastTickLiveSpans []completedSpan
)

func clearLiveEvents() {
	liveEvents = nil
	liveGraphRev = 0
	lastTickLiveSpans = nil
}

func bumpLiveGraph() {
	liveGraphRev++
}

func pushLiveEvent(kind, text string) {
	liveEvents = append(liveEvents, liveEvent{
		At:   time.Now().Format("15:04:05.000"),
		Kind: kind,
		Text: text,
	})
	if len(liveEvents) > maxLiveEvents {
		liveEvents = liveEvents[len(liveEvents)-maxLiveEvents:]
	}
}

func setLastTickLiveSpans(spans []completedSpan) {
	lastTickLiveSpans = append([]completedSpan(nil), spans...)
	bumpLiveGraph()
}

// collectLiveDisplaySpans returns spans for one tick only (in-progress or last completed).
func collectLiveDisplaySpansLocked(now int64) []completedSpan {
	if state.tickOpen {
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
			dur := end - rec.startNs
			if dur <= 0 {
				continue
			}
			out = append(out, completedSpan{
				name:    rec.name,
				ctx:     rec.ctx,
				startNs: rec.startNs,
				endNs:   end,
				stack:   buildStackNames(rec, state.spans),
			})
		}
		return out
	}
	return append([]completedSpan(nil), lastTickLiveSpans...)
}

func liveFlameRootName() string {
	if state.tickOpen {
		return fmt.Sprintf("tick %d (live)", state.tickSampleNum+1)
	}
	if state.tickSampleNum > 0 {
		return fmt.Sprintf("tick %d", state.tickSampleNum)
	}
	return "tick"
}

func collectLiveTopSpansLocked(now int64) []completedSpan {
	return collectLiveDisplaySpansLocked(now)
}

func spanStackLabel(rec *spanRecord) string {
	stack := buildStackNames(rec, state.spans)
	if len(stack) == 0 {
		return rec.name
	}
	return strings.Join(stack, " → ")
}
