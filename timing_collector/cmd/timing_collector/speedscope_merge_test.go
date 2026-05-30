package main

import "testing"

func TestMergeTickProfilesConcatenatesTicks(t *testing.T) {
	perTick := []speedscopeEventedProfile{
		{
			Name: "tick 1",
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "O", At: 100, Frame: 1},
				{Type: "C", At: 200, Frame: 1},
				{Type: "C", At: 300, Frame: 0},
			},
			EndValue: 300,
		},
		{
			Name: "tick 2",
			Events: []speedscopeEvent{
				{Type: "O", At: 0, Frame: 0},
				{Type: "O", At: 100, Frame: 1},
				{Type: "C", At: 200, Frame: 1},
				{Type: "C", At: 300, Frame: 0},
			},
			EndValue: 300,
		},
	}
	events, start, end, err := mergeTickProfiles(perTick)
	if err != nil {
		t.Fatal(err)
	}
	if start != 0 {
		t.Fatalf("start=%d want 0", start)
	}
	wantEnd := int64(300 + tickTimelineGapNs + 300)
	if end != wantEnd {
		t.Fatalf("end=%d want %d", end, wantEnd)
	}
	if len(events) != 8 {
		t.Fatalf("events=%d want 8", len(events))
	}
	if events[4].At < 300+tickTimelineGapNs {
		t.Fatalf("tick2 start at=%d too early", events[4].At)
	}
}

func TestAverageTickProfile(t *testing.T) {
	tick := func(ns int64) []speedscopeEvent {
		return []speedscopeEvent{
			{Type: "O", At: 0, Frame: 0},
			{Type: "O", At: 0, Frame: 1},
			{Type: "C", At: ns, Frame: 1},
			{Type: "C", At: ns * 2, Frame: 0},
		}
	}
	perTick := []speedscopeEventedProfile{
		{Name: "tick 1", Events: tick(100), EndValue: 200},
		{Name: "tick 2", Events: tick(300), EndValue: 600},
	}
	avg, err := averageTickProfile(perTick)
	if err != nil {
		t.Fatal(err)
	}
	if avg.Name != "Average tick" {
		t.Fatalf("name=%q", avg.Name)
	}
	durs := frameExclusiveDurations(avg.Events)
	if durs[1] != 200 {
		t.Fatalf("avg child frame dur=%d want 200", durs[1])
	}
}

func TestBuildSpeedscopeProfilesHasThreeViews(t *testing.T) {
	perTick := []speedscopeEventedProfile{
		{Name: "tick 1", Events: []speedscopeEvent{{Type: "O", At: 0, Frame: 0}, {Type: "C", At: 10, Frame: 0}}, EndValue: 10},
		{Name: "tick 2", Events: []speedscopeEvent{{Type: "O", At: 0, Frame: 0}, {Type: "C", At: 20, Frame: 0}}, EndValue: 20},
	}
	profiles, err := buildSpeedscopeProfiles(perTick, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(profiles) != 3 {
		t.Fatalf("profiles=%d want 3", len(profiles))
	}
	if profiles[1].Name != "Average tick" || profiles[2].Name != "Last tick" {
		t.Fatalf("names: %q %q", profiles[1].Name, profiles[2].Name)
	}
}

func TestMergedTickProfilePrefersPerTick(t *testing.T) {
	perTick := []speedscopeEventedProfile{{
		Name: "tick 1",
		Events: []speedscopeEvent{
			{Type: "O", At: 0, Frame: 0},
			{Type: "C", At: 100, Frame: 0},
		},
		EndValue: 100,
	}}
	prof, err := mergedTickProfile(perTick, nil)
	if err != nil {
		t.Fatal(err)
	}
	if prof.Name != "ALL ticks (merged)" {
		t.Fatalf("name=%q", prof.Name)
	}
	if len(prof.Events) != 2 {
		t.Fatalf("events=%d", len(prof.Events))
	}
}
