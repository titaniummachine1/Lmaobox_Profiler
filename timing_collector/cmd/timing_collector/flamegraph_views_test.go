package main

import (
	"strconv"
	"strings"
	"testing"
)

func foldedTotalNs(spans []completedSpan, root string) int64 {
	lines, err := foldedLinesFromSpans(spans, root)
	if err != nil {
		return -1
	}
	var total int64
	for _, line := range lines {
		i := strings.LastIndex(line, " ")
		if i < 0 {
			continue
		}
		v, err := strconv.ParseInt(line[i+1:], 10, 64)
		if err == nil {
			total += v
		}
	}
	return total
}

func TestMergedSpansFromTicksSumsAllBatches(t *testing.T) {
	batches := [][]completedSpan{
		{{name: "leaf", stack: []string{"root", "leaf"}, startNs: 0, endNs: 100, ctx: "tick"}},
		{{name: "leaf", stack: []string{"root", "leaf"}, startNs: 0, endNs: 300, ctx: "tick"}},
	}
	merged := mergedSpansFromTicks(batches)
	if len(merged) != 2 {
		t.Fatalf("merged len=%d want 2 leaf spans", len(merged))
	}
	total := foldedTotalNs(merged, "script")
	if total != 400 {
		t.Fatalf("folded total=%d want 400", total)
	}
}

func TestAverageSpansIncludesAllStacks(t *testing.T) {
	batches := [][]completedSpan{
		{{name: "a", stack: []string{"root", "a"}, startNs: 0, endNs: 100, ctx: "tick"}},
		{
			{name: "b", stack: []string{"root", "b"}, startNs: 0, endNs: 200, ctx: "tick"},
			{name: "a", stack: []string{"root", "a"}, startNs: 0, endNs: 300, ctx: "tick"},
		},
	}
	avg := averageSpansFromTicks(batches)
	if len(avg) != 2 {
		t.Fatalf("avg stacks=%d want 2 (a and b)", len(avg))
	}
	byKey := map[string]int64{}
	for _, s := range avg {
		byKey[stackKey(s.stack, s.name)] = spanDurationNs(s)
	}
	if byKey["root;a"] != 200 {
		t.Fatalf("avg a=%d want 200", byKey["root;a"])
	}
	if byKey["root;b"] != 200 {
		t.Fatalf("avg b=%d want 200", byKey["root;b"])
	}
}

func TestLastTickSpansFromBatches(t *testing.T) {
	batches := [][]completedSpan{
		{{name: "old", stack: []string{"root"}, startNs: 0, endNs: 10, ctx: "tick"}},
		{{name: "new", stack: []string{"root"}, startNs: 0, endNs: 99, ctx: "tick"}},
	}
	last := lastTickSpansFromBatches(batches)
	if len(last) != 1 || last[0].name != "new" {
		t.Fatalf("last=%+v", last)
	}
}
