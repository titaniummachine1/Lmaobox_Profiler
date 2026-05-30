package main

import (
	"strings"
	"testing"
)

func TestBuildTimelineSegmentsTwoTicks(t *testing.T) {
	perTick := []speedscopeEventedProfile{
		{
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "C", At: 100, Frame: 0},
			},
		},
		{
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "C", At: 100, Frame: 0},
			},
		},
	}
	events, _, end, tickStarts, err := mergeTickProfiles(perTick)
	if err != nil {
		t.Fatal(err)
	}
	if len(tickStarts) != 2 {
		t.Fatalf("tickStarts=%d want 2", len(tickStarts))
	}
	segments := buildTimelineSegments(events)
	if len(segments) < 2 {
		t.Fatalf("segments=%d want at least 2", len(segments))
	}
	if segments[0].to-segments[0].from != 100 {
		t.Fatalf("first segment dur=%d want 100", segments[0].to-segments[0].from)
	}
	if end <= 100 {
		t.Fatalf("end=%d too small", end)
	}
}

func TestRenderTimelineFlamegraphSVG(t *testing.T) {
	perTick := []speedscopeEventedProfile{
		{
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "O", At: 10, Frame: 1},
				{Type: "C", At: 90, Frame: 1},
				{Type: "C", At: 100, Frame: 0},
			},
		},
		{
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "C", At: 50, Frame: 0},
			},
		},
	}
	frameMap := map[string]int{"root": 0, "child": 1}
	svg, err := renderTimelineFlamegraphBytes(perTick, frameMap, "test timeline")
	if err != nil {
		t.Fatal(err)
	}
	body := string(svg)
	if !strings.Contains(body, `class="fg"`) {
		t.Fatal("missing flame rects")
	}
	if !strings.Contains(body, "tick-mark") {
		t.Fatal("missing tick boundary marks")
	}
	if !strings.Contains(body, "timeline") {
		t.Fatal("missing title")
	}
}
