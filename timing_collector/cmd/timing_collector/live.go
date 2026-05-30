package main

import (
	"encoding/json"
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

// All tick spans recorded this session (+ current tick in progress).
func collectLiveSessionSpansLocked(now int64) []completedSpan {
	out := append([]completedSpan(nil), state.tickSpans...)
	if !state.tickOpen {
		return out
	}
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

func collectLiveDisplaySpansLocked(now int64) []completedSpan {
	return collectLiveSessionSpansLocked(now)
}

func collectLiveTopSpansLocked(now int64) []completedSpan {
	return collectLiveSessionSpansLocked(now)
}

func liveFlameRootName() string {
	n := state.tickSampleNum
	if state.tickOpen {
		n++
	}
	if n <= 0 {
		return state.scriptName
	}
	if state.scriptName != "" {
		return fmt.Sprintf("%s — %d ticks", state.scriptName, n)
	}
	return fmt.Sprintf("%d ticks", n)
}

func liveSpeedscopeMetaLocked() ([]string, int) {
	if len(state.tickProfiles) == 0 && len(state.tickEvents) < 2 {
		return []string{"ALL ticks (merged)"}, 0
	}
	return speedscopeProfileNames(state.tickProfiles), 0
}

func buildLiveSpeedscopeLocked() ([]byte, []string, int, error) {
	frameMap := frameNameToIndex["tick"]
	if len(frameMap) == 0 {
		return nil, nil, 0, fmt.Errorf("no frame map")
	}

	profiles, err := buildSpeedscopeProfiles(state.tickProfiles, state.tickEvents)
	if err != nil {
		return nil, nil, 0, err
	}
	active := 0

	file, err := buildSpeedscopeFile(frameMap, profiles, active)
	if err != nil {
		return nil, nil, 0, err
	}
	b, err := json.Marshal(file)
	if err != nil {
		return nil, nil, 0, err
	}
	names := make([]string, len(profiles))
	for i, p := range profiles {
		names[i] = p.Name
	}
	return b, names, active, nil
}

func spanStackLabel(rec *spanRecord) string {
	stack := buildStackNames(rec, state.spans)
	if len(stack) == 0 {
		return rec.name
	}
	return strings.Join(stack, " → ")
}
