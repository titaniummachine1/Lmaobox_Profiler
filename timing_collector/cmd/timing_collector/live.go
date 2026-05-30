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

func collectLiveTopSpansLocked(now int64) []completedSpan {
	return mergedSpansForLiveLocked(now)
}

func liveFlameRootName() string {
	n := tickCountForFlameTitles()
	if n <= 0 {
		return state.scriptName
	}
	if state.scriptName != "" {
		return fmt.Sprintf("%s — %d ticks (merged)", state.scriptName, n)
	}
	return fmt.Sprintf("%d ticks (merged)", n)
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
	profiles, err = sanitizeSpeedscopeProfiles(profiles)
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
