package main

import "testing"

func TestNormalizeSpanEnd(t *testing.T) {
	if got := normalizeSpanEnd(100, 100); got != 101 {
		t.Fatalf("got %d want 101", got)
	}
	if got := normalizeSpanEnd(100, 500); got != 500 {
		t.Fatalf("got %d want 500", got)
	}
}

func TestSpanDurationNsFromBounds(t *testing.T) {
	if d := spanDurationNsFromBounds(10, 10); d != 1 {
		t.Fatalf("zero-length span=%d want 1", d)
	}
	if d := spanDurationNsFromBounds(10, 1000); d != 990 {
		t.Fatalf("dur=%d want 990", d)
	}
}
