package main

import "testing"

func TestEnforceMonotonicEventTimes(t *testing.T) {
	events := []speedscopeEvent{
		{Type: "O", At: 10, Frame: 0},
		{Type: "C", At: 20, Frame: 0},
		{Type: "O", At: 19, Frame: 1},
		{Type: "C", At: 30, Frame: 1},
	}
	out := enforceMonotonicEventTimes(events)
	if out[2].At <= out[1].At {
		t.Fatalf("open at %d should be after close at %d", out[2].At, out[1].At)
	}
	if err := validateEventedStack(out); err != nil {
		t.Fatal(err)
	}
}

func TestSanitizeMergedProfileFromCheaterPattern(t *testing.T) {
	events := []speedscopeEvent{
		{Type: "O", At: 0, Frame: 0},
		{Type: "O", At: 0, Frame: 1},
		{Type: "C", At: 100, Frame: 1},
		{Type: "O", At: 99, Frame: 2},
		{Type: "C", At: 200, Frame: 2},
		{Type: "C", At: 250, Frame: 0},
	}
	p := speedscopeEventedProfile{
		Type: "evented", Name: "test", Unit: "nanoseconds",
		StartValue: 0, EndValue: 250, Events: events,
	}
	sanitized, err := sanitizeEventedProfile(p)
	if err != nil {
		t.Fatal(err)
	}
	if err := validateEventedStack(sanitized.Events); err != nil {
		t.Fatal(err)
	}
}
