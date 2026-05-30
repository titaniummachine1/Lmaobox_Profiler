package main

import "strings"

// spansForFlamegraph keeps only leaf spans so parent inclusive durations are not
// double-counted with their children in folded / inferno output.
func spansForFlamegraph(spans []completedSpan) []completedSpan {
	if len(spans) <= 1 {
		return spans
	}
	keys := make([]string, len(spans))
	for i, s := range spans {
		stack := s.stack
		if len(stack) == 0 {
			stack = []string{s.name}
		}
		keys[i] = strings.Join(stack, ";")
	}
	out := make([]completedSpan, 0, len(spans))
	for i, s := range spans {
		prefix := keys[i] + ";"
		isParent := false
		for j, k := range keys {
			if i != j && strings.HasPrefix(k, prefix) {
				isParent = true
				break
			}
		}
		if !isParent {
			out = append(out, s)
		}
	}
	return out
}
