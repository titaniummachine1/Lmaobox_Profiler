package main

import (
	"encoding/json"
	"testing"
)

func TestAutoTickRolloverOnRepeatedRootSpan(t *testing.T) {
	resetSessionLocked()
	state.sessionID = "test"
	state.scriptName = "t"
	state.activeCtx = "tick"
	frameNameToIndex["tick"] = map[string]int{"CreateMove_Total": 0, "child": 1}

	// First tick (no explicit BeginTick)
	maybeBeginTickOnRootSpanLocked("CreateMove_Total")
	appendOpenEventLocked("tick", "CreateMove_Total", 0)
	appendOpenEventLocked("tick", "child", 10)
	appendCloseEventLocked("tick", "child", 50)
	appendCloseEventLocked("tick", "CreateMove_Total", 100)

	if !state.tickOpen {
		t.Fatal("first tick should be open")
	}

	// Second tick: same root name again
	maybeBeginTickOnRootSpanLocked("CreateMove_Total")
	if state.tickSampleNum != 1 {
		t.Fatalf("after rollover want 1 captured tick, got %d", state.tickSampleNum)
	}
	if len(state.tickProfiles) != 1 {
		t.Fatalf("tickProfiles=%d want 1", len(state.tickProfiles))
	}
}

func TestSpeedscopeJSONForView(t *testing.T) {
	raw, err := buildSpeedscopeFile(
		map[string]int{"a": 0},
		[]speedscopeEventedProfile{
			{Name: "ALL ticks (merged)", Type: "evented", Unit: "ns", StartValue: 0, EndValue: 10,
				Events: []speedscopeEvent{{Type: "O", At: 0, Frame: 0}, {Type: "C", At: 10, Frame: 0}}},
			{Name: "Average tick", Type: "evented", Unit: "ns", StartValue: 0, EndValue: 5,
				Events: []speedscopeEvent{{Type: "O", At: 0, Frame: 0}, {Type: "C", At: 5, Frame: 0}}},
		},
		0,
	)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(raw)
	out := speedscopeJSONForView(b, 1)
	var file speedscopeFile
	if err := json.Unmarshal(out, &file); err != nil {
		t.Fatal(err)
	}
	if file.ActiveProfileIndex != 1 {
		t.Fatalf("active=%d want 1", file.ActiveProfileIndex)
	}
	if file.Profiles[file.ActiveProfileIndex].Name != "Average tick" {
		t.Fatalf("profile name=%q", file.Profiles[file.ActiveProfileIndex].Name)
	}
}
