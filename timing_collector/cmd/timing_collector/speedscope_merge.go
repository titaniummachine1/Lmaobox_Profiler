package main

import (
	"encoding/json"
	"fmt"
)

// Gap between consecutive ticks in the merged speedscope timeline (visible separation when zoomed).
const tickTimelineGapNs = int64(500_000) // 0.5 ms

func waitingSpeedscopeJSON() []byte {
	file, err := buildSpeedscopeFile(
		map[string]int{"waiting": 0},
		[]speedscopeEventedProfile{{
			Type:       "evented",
			Name:       "Waiting for ticks",
			Unit:       "nanoseconds",
			StartValue: 0,
			EndValue:   1,
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "C", At: 1, Frame: 0},
			},
		}},
		0,
	)
	if err != nil {
		return []byte(`{"$schema":"https://www.speedscope.app/file-format-schema.json","shared":{"frames":[{"name":"waiting"}]},"profiles":[{"type":"evented","name":"waiting","unit":"nanoseconds","startValue":0,"endValue":1,"events":[{"type":"O","at":0,"frame":0},{"type":"C","at":1,"frame":0}]}],"activeProfileIndex":0}`)
	}
	b, _ := json.Marshal(file)
	return b
}

// mergeTickProfiles lays each completed tick profile end-to-end so Time Order shows all ticks
// in one continuous zoomable timeline (tick 1, tick 2, …).
func mergeTickProfiles(perTick []speedscopeEventedProfile) ([]speedscopeEvent, int64, int64, error) {
	if len(perTick) == 0 {
		return nil, 0, 0, fmt.Errorf("no per-tick profiles")
	}
	merged := make([]speedscopeEvent, 0, 64)
	cursor := int64(0)
	ticksAdded := 0
	for _, prof := range perTick {
		chunk := rebaseEvents(prof.Events)
		if len(chunk) < 2 {
			continue
		}
		if ticksAdded > 0 {
			cursor += tickTimelineGapNs
		}
		for _, e := range chunk {
			merged = append(merged, speedscopeEvent{
				Type:  e.Type,
				At:    cursor + e.At,
				Frame: e.Frame,
			})
		}
		cursor = merged[len(merged)-1].At
		ticksAdded++
	}
	if len(merged) < 2 || ticksAdded == 0 {
		return nil, 0, 0, fmt.Errorf("not enough events for merged timeline")
	}
	merged = enforceMonotonicEventTimes(merged)
	return merged, merged[0].At, merged[len(merged)-1].At, nil
}

// frameExclusiveDurations maps each frame to self time (inclusive minus nested children) per tick.
func frameExclusiveDurations(events []speedscopeEvent) map[int]int64 {
	type openRec struct {
		frame          int
		at             int64
		childInclusive int64
	}
	var stack []openRec
	durs := map[int]int64{}
	for _, e := range events {
		if e.Type == "O" {
			stack = append(stack, openRec{frame: e.Frame, at: e.At})
			continue
		}
		if len(stack) == 0 {
			continue
		}
		top := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if top.frame != e.Frame {
			continue
		}
		inclusive := e.At - top.at
		if inclusive <= 0 {
			continue
		}
		exclusive := inclusive - top.childInclusive
		if exclusive > 0 {
			durs[e.Frame] += exclusive
		}
		if len(stack) > 0 {
			parent := stack[len(stack)-1]
			parent.childInclusive += inclusive
			stack[len(stack)-1] = parent
		}
	}
	return durs
}

func averageTickProfile(perTick []speedscopeEventedProfile) (speedscopeEventedProfile, error) {
	if len(perTick) == 0 {
		return speedscopeEventedProfile{}, fmt.Errorf("no ticks for average")
	}
	type stat struct {
		sum int64
		n   int64
	}
	avgDur := map[int]stat{}
	for _, prof := range perTick {
		durs := frameExclusiveDurations(rebaseEvents(prof.Events))
		for f, d := range durs {
			s := avgDur[f]
			s.sum += d
			s.n++
			avgDur[f] = s
		}
	}
	template := rebaseEvents(perTick[len(perTick)-1].Events)
	if len(template) < 2 {
		return speedscopeEventedProfile{}, fmt.Errorf("average: template too short")
	}
	out := make([]speedscopeEvent, 0, len(template))
	cursor := int64(0)
	for _, e := range template {
		if e.Type == "O" {
			out = append(out, speedscopeEvent{Type: "O", At: cursor, Frame: e.Frame})
			continue
		}
		dur := int64(1)
		if s, ok := avgDur[e.Frame]; ok && s.n > 0 {
			dur = s.sum / s.n
			if dur < 1 {
				dur = 1
			}
		}
		cursor += dur
		out = append(out, speedscopeEvent{Type: "C", At: cursor, Frame: e.Frame})
	}
	return speedscopeEventedProfile{
		Type:       "evented",
		Name:       "Average tick",
		Unit:       "nanoseconds",
		StartValue: out[0].At,
		EndValue:   out[len(out)-1].At,
		Events:     out,
	}, nil
}

func lastTickProfile(perTick []speedscopeEventedProfile) (speedscopeEventedProfile, error) {
	if len(perTick) == 0 {
		return speedscopeEventedProfile{}, fmt.Errorf("no ticks")
	}
	last := perTick[len(perTick)-1]
	events := rebaseEvents(append([]speedscopeEvent(nil), last.Events...))
	if len(events) < 2 {
		return speedscopeEventedProfile{}, fmt.Errorf("last tick: too short")
	}
	return speedscopeEventedProfile{
		Type:       "evented",
		Name:       "Last tick",
		Unit:       "nanoseconds",
		StartValue: events[0].At,
		EndValue:   events[len(events)-1].At,
		Events:     events,
	}, nil
}

// buildSpeedscopeProfiles: merged timeline, mean tick shape, and most recent tick only.
func buildSpeedscopeProfiles(perTick []speedscopeEventedProfile, fallback []speedscopeEvent) ([]speedscopeEventedProfile, error) {
	merged, err := mergedTickProfile(perTick, fallback)
	if err != nil {
		return nil, err
	}
	profiles := []speedscopeEventedProfile{merged}
	if len(perTick) == 0 {
		return profiles, nil
	}
	if avg, err := averageTickProfile(perTick); err == nil {
		profiles = append(profiles, avg)
	}
	if last, err := lastTickProfile(perTick); err == nil {
		profiles = append(profiles, last)
	}
	return profiles, nil
}

func speedscopeProfileNames(perTick []speedscopeEventedProfile) []string {
	if len(perTick) == 0 {
		return []string{"ALL ticks (merged)"}
	}
	return []string{"ALL ticks (merged)", "Average tick", "Last tick"}
}

func mergedTickProfile(perTick []speedscopeEventedProfile, fallback []speedscopeEvent) (speedscopeEventedProfile, error) {
	if events, start, end, err := mergeTickProfiles(perTick); err == nil {
		return speedscopeEventedProfile{
			Type:       "evented",
			Name:       "ALL ticks (merged)",
			Unit:       "nanoseconds",
			StartValue: start,
			EndValue:   end,
			Events:     events,
		}, nil
	}
	if len(fallback) < 2 {
		return speedscopeEventedProfile{}, fmt.Errorf("not enough speedscope events")
	}
	compressed := compressEventTimeline(append([]speedscopeEvent(nil), fallback...))
	start := compressed[0].At
	end := compressed[len(compressed)-1].At
	if end <= start {
		return speedscopeEventedProfile{}, fmt.Errorf("zero duration merged profile")
	}
	return speedscopeEventedProfile{
		Type:       "evented",
		Name:       "ALL ticks (merged)",
		Unit:       "nanoseconds",
		StartValue: start,
		EndValue:   end,
		Events:     compressed,
	}, nil
}
