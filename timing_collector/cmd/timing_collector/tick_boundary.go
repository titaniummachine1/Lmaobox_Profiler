package main

import "fmt"

// tickRootBoundary is the top-level span name (e.g. CreateMove_Total) used to detect
// a new game tick when BeginTick was skipped but the same root opens again.

func tickEventsInCurrentOpen() int {
	return len(state.tickEvents) - state.tickEventsStart
}

func autoBeginTickLocked(reason string) {
	if state.tickOpen {
		return
	}
	closeOpenSpansLocked("tick")
	state.activeCtx = "tick"
	state.tickOpen = true
	state.tickEventsStart = len(state.tickEvents)
	pushLiveEvent("tick", fmt.Sprintf("Tick %d begin (%s)", state.tickSampleNum+1, reason))
}

func rolloverTickLocked(reason string) {
	if !state.tickOpen {
		return
	}
	if tickEventsInCurrentOpen() < 2 {
		return
	}
	captureTickProfileLocked()
	flushCtxSpansLocked("tick")
	state.tickOpen = true
	state.tickEventsStart = len(state.tickEvents)
	pushLiveEvent("tick", fmt.Sprintf("Tick %d begin (%s)", state.tickSampleNum+1, reason))
}

// maybeBeginTickOnRootSpan runs when a depth-0 span starts in tick context.
func maybeBeginTickOnRootSpanLocked(rootName string) {
	if rootName == "" {
		return
	}
	if state.tickRootBoundary == "" {
		state.tickRootBoundary = rootName
		if !state.tickOpen {
			autoBeginTickLocked("root span")
		}
		return
	}
	if rootName != state.tickRootBoundary {
		return
	}
	if !state.tickOpen {
		autoBeginTickLocked("root span")
		return
	}
	if tickEventsInCurrentOpen() >= 2 {
		rolloverTickLocked("same root span")
	}
}

func maybeBeginTickOnReportRootLocked(rootName string) {
	maybeBeginTickOnRootSpanLocked(rootName)
}

func tickRootFromStack(stack []string, name string) string {
	if len(stack) > 0 {
		return stack[0]
	}
	return name
}

func resetTickBoundaryLocked() {
	state.tickRootBoundary = ""
}
