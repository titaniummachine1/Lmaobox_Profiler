// timing_collector — local HTTP profiler collector for Lmaobox Lua (stdlib only).
// Listens on 127.0.0.1:9876. Lua uses http.Get for all endpoints.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	listenAddr         = "127.0.0.1:9876"
	sessionIdleTimeout = 3 * time.Second
	idleCheckInterval  = 250 * time.Millisecond
)

var (
	serverStart = time.Now()
	mu          sync.Mutex
	state       collectorState
	// lastActivity is updated only after the first tick/frame/span (not session/begin).
	lastActivity     time.Time
	profilingStarted bool
)

type collectorState struct {
	sessionID    string
	scriptName   string
	sessionStart time.Time

	activeCtx string // "tick" | "frame" | ""

	tickOpen  bool
	frameOpen bool

	nextSpanID uint64
	spans      map[uint64]*spanRecord
	openStack  []uint64

	// Per-context completed spans for export (aggregated across ticks/frames in session)
	tickSpans  []completedSpan
	frameSpans []completedSpan

	// Speedscope event buffers per context (reset each tick/frame end export slice append)
	tickEvents  []speedscopeEvent
	frameEvents []speedscopeEvent
}

type spanRecord struct {
	id      uint64
	name    string
	ctx     string
	parent  uint64
	startNs int64
	endNs   int64
	closed  bool
}

type completedSpan struct {
	name    string
	ctx     string
	startNs int64
	endNs   int64
	stack   []string
}

type speedscopeEvent struct {
	Type  string `json:"type"`
	At    int64  `json:"at"`
	Frame int    `json:"frame,omitempty"`
}

type speedscopeProfile struct {
	Type      string            `json:"$schema"`
	Name      string            `json:"name"`
	Unit      string            `json:"unit"`
	StartTime int64             `json:"startValue"`
	EndTime   int64             `json:"endValue"`
	Events    []speedscopeEvent `json:"events"`
	Frames    []string          `json:"frames"`
}

func main() {
	state = collectorState{
		spans: make(map[uint64]*spanRecord),
	}
	outDir := flameGraphsDir()
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		log.Fatalf("mkdir flame_graphs: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/now", handleNow)
	mux.HandleFunc("/session/begin", handleSessionBegin)
	mux.HandleFunc("/session/end", handleSessionEnd)
	mux.HandleFunc("/tick/begin", handleTickBegin)
	mux.HandleFunc("/tick/end", handleTickEnd)
	mux.HandleFunc("/frame/begin", handleFrameBegin)
	mux.HandleFunc("/frame/end", handleFrameEnd)
	mux.HandleFunc("/span/start", handleSpanStart)
	mux.HandleFunc("/span/end", handleSpanEnd)
	mux.HandleFunc("/span/report", handleSpanReport)

	startIdleWatcher()

	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "timing_collector: cannot listen on %s: %v\n", listenAddr, err)
		fmt.Fprintf(os.Stderr, "Another timing_collector or the old Rust server may already be using port 9876.\n")
		waitBeforeExit()
		os.Exit(1)
	}

	log.Printf("timing_collector on http://%s (flame_graphs: %s)", listenAddr, outDir)
	log.Printf("idle export: %v after last tick/frame/span (not after session/begin alone)", sessionIdleTimeout)
	log.Fatal(http.Serve(ln, mux))
}

func waitBeforeExit() {
	fmt.Fprint(os.Stderr, "Press Enter to close...")
	_, _ = bufio.NewReader(os.Stdin).ReadBytes('\n')
}

func markProfilingActivity() {
	profilingStarted = true
	lastActivity = time.Now()
}

func startIdleWatcher() {
	go func() {
		for {
			time.Sleep(idleCheckInterval)
			mu.Lock()
			if state.sessionID != "" && profilingStarted && !lastActivity.IsZero() {
				if time.Since(lastActivity) >= sessionIdleTimeout {
					log.Printf("session %s idle for %v — exporting flame_graphs", state.sessionID, sessionIdleTimeout)
					endSessionLocked("idle_timeout")
				}
			}
			mu.Unlock()
		}
	}()
}

// endSessionLocked exports and clears the active session (same outcome as /session/end).
func endSessionLocked(reason string) {
	if state.sessionID == "" {
		return
	}
	sid := state.sessionID

	if state.tickOpen {
		flushCtxSpansLocked("tick")
		state.tickOpen = false
	}
	if state.frameOpen {
		flushCtxSpansLocked("frame")
		state.frameOpen = false
	}
	state.activeCtx = ""

	exportSessionLocked(reason)
	resetSessionLocked()
	log.Printf("session %s ended (%s)", sid, reason)
}

func flameGraphsDir() string {
	if exe, err := os.Executable(); err == nil {
		return filepath.Join(filepath.Dir(exe), "flame_graphs")
	}
	return "flame_graphs"
}

func handleNow(w http.ResponseWriter, r *http.Request) {
	ns := time.Since(serverStart).Nanoseconds()
	fmt.Fprintf(w, "%d", ns)
}

func handleSessionBegin(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()

	script := queryUnescape(r, "script")
	if script == "" {
		script = "unknown"
	}

	if state.sessionID != "" {
		endSessionLocked("session_begin")
	}

	state.sessionID = fmt.Sprintf("%s_%d", sanitizeFileName(script), time.Now().UnixNano())
	state.scriptName = script
	state.sessionStart = time.Now()
	state.activeCtx = ""
	state.tickOpen = false
	state.frameOpen = false
	state.nextSpanID = 1
	state.spans = make(map[uint64]*spanRecord)
	state.openStack = nil
	state.tickSpans = nil
	state.frameSpans = nil
	state.tickEvents = nil
	state.frameEvents = nil
	frameNameToIndex = map[string]map[string]int{}
	profilingStarted = false
	lastActivity = time.Time{}

	fmt.Fprintf(w, "%s", state.sessionID)
}

func handleSessionEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()

	if state.sessionID == "" {
		fmt.Fprint(w, "0")
		return
	}
	endSessionLocked("api")
	fmt.Fprint(w, "1")
}

func handleTickBegin(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()
	if state.sessionID == "" {
		fmt.Fprint(w, "-1")
		return
	}
	closeOpenSpansLocked("tick")
	state.activeCtx = "tick"
	state.tickOpen = true
	fmt.Fprint(w, "0")
}

func handleTickEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()
	if !state.tickOpen {
		fmt.Fprint(w, "-1")
		return
	}
	flushCtxSpansLocked("tick")
	state.tickOpen = false
	if state.activeCtx == "tick" {
		state.activeCtx = ""
	}
	fmt.Fprint(w, "0")
}

func handleFrameBegin(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()
	if state.sessionID == "" {
		fmt.Fprint(w, "-1")
		return
	}
	closeOpenSpansLocked("frame")
	state.activeCtx = "frame"
	state.frameOpen = true
	fmt.Fprint(w, "0")
}

func handleFrameEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()
	if !state.frameOpen {
		fmt.Fprint(w, "-1")
		return
	}
	flushCtxSpansLocked("frame")
	state.frameOpen = false
	if state.activeCtx == "frame" {
		state.activeCtx = ""
	}
	fmt.Fprint(w, "0")
}

func handleSpanStart(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()

	if state.sessionID == "" || state.activeCtx == "" {
		fmt.Fprint(w, "-1")
		return
	}

	name := queryUnescape(r, "name")
	if name == "" {
		fmt.Fprint(w, "-1")
		return
	}
	ctx := queryUnescape(r, "ctx")
	if ctx == "" {
		ctx = state.activeCtx
	}

	parent := uint64(0)
	if ps := r.URL.Query().Get("parent"); ps != "" {
		if v, err := strconv.ParseUint(ps, 10, 64); err == nil {
			parent = v
		}
	}

	id := state.nextSpanID
	state.nextSpanID++
	startNs := time.Since(serverStart).Nanoseconds()

	rec := &spanRecord{
		id:      id,
		name:    name,
		ctx:     ctx,
		parent:  parent,
		startNs: startNs,
	}
	state.spans[id] = rec
	state.openStack = append(state.openStack, id)

	appendOpenEventLocked(ctx, name, startNs)

	fmt.Fprintf(w, "%d", id)
}

func handleSpanEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()

	spanIDStr := r.URL.Query().Get("span_id")
	if spanIDStr == "" {
		spanIDStr = r.URL.Query().Get("id")
	}
	spanID, err := strconv.ParseUint(spanIDStr, 10, 64)
	if err != nil {
		fmt.Fprint(w, "-1")
		return
	}

	rec, ok := state.spans[spanID]
	if !ok || rec.closed {
		fmt.Fprint(w, "-1")
		return
	}

	endNs := time.Since(serverStart).Nanoseconds()
	rec.endNs = endNs
	rec.closed = true

	appendCloseEventLocked(rec.ctx, rec.name, endNs)

	// Pop from stack if top matches
	for len(state.openStack) > 0 {
		top := state.openStack[len(state.openStack)-1]
		state.openStack = state.openStack[:len(state.openStack)-1]
		if top == spanID {
			break
		}
	}

	fmt.Fprintf(w, "%d", endNs-rec.startNs)
}

// handleSpanReport ingests a completed span from Lua (buffered flush — no per-Begin HTTP).
// GET /span/report?name=&ctx=tick|frame&dur_ns=&stack=parent;child
func handleSpanReport(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()

	if state.sessionID == "" {
		fmt.Fprint(w, "-1")
		return
	}

	name := queryUnescape(r, "name")
	ctx := queryUnescape(r, "ctx")
	if name == "" || (ctx != "tick" && ctx != "frame") {
		fmt.Fprint(w, "-1")
		return
	}

	durNs, err := strconv.ParseInt(r.URL.Query().Get("dur_ns"), 10, 64)
	if err != nil || durNs < 0 {
		fmt.Fprint(w, "-1")
		return
	}

	stackStr := queryUnescape(r, "stack")
	var stack []string
	if stackStr != "" {
		for _, part := range strings.Split(stackStr, ";") {
			if part != "" {
				stack = append(stack, part)
			}
		}
	}
	if len(stack) == 0 {
		stack = []string{name}
	}

	endNs := time.Since(serverStart).Nanoseconds()
	startNs := endNs - durNs
	if startNs < 0 {
		startNs = 0
	}

	appendOpenEventLocked(ctx, name, startNs)
	appendCloseEventLocked(ctx, name, endNs)

	completed := completedSpan{
		name:    name,
		ctx:     ctx,
		startNs: startNs,
		endNs:   endNs,
		stack:   stack,
	}
	if ctx == "tick" {
		state.tickSpans = append(state.tickSpans, completed)
	} else {
		state.frameSpans = append(state.frameSpans, completed)
	}

	fmt.Fprint(w, "0")
}

func closeOpenSpansLocked(ctx string) {
	now := time.Since(serverStart).Nanoseconds()
	for len(state.openStack) > 0 {
		id := state.openStack[len(state.openStack)-1]
		state.openStack = state.openStack[:len(state.openStack)-1]
		rec := state.spans[id]
		if rec == nil || rec.closed {
			continue
		}
		if rec.ctx != ctx {
			continue
		}
		rec.endNs = now
		rec.closed = true
		appendCloseEventLocked(rec.ctx, rec.name, now)
	}
}

func flushCtxSpansLocked(ctx string) {
	now := time.Since(serverStart).Nanoseconds()
	var completed []completedSpan
	for _, id := range collectSpanIDs(state.spans) {
		rec := state.spans[id]
		if rec == nil || rec.ctx != ctx {
			continue
		}
		if !rec.closed {
			rec.endNs = now
			rec.closed = true
			appendCloseEventLocked(ctx, rec.name, now)
		}
		stack := buildStackNames(rec, state.spans)
		completed = append(completed, completedSpan{
			name:    rec.name,
			ctx:     rec.ctx,
			startNs: rec.startNs,
			endNs:   rec.endNs,
			stack:   stack,
		})
		delete(state.spans, id)
	}
	state.openStack = nil

	if ctx == "tick" {
		state.tickSpans = append(state.tickSpans, completed...)
	} else {
		state.frameSpans = append(state.frameSpans, completed...)
	}
}

func collectSpanIDs(m map[uint64]*spanRecord) []uint64 {
	ids := make([]uint64, 0, len(m))
	for id := range m {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	return ids
}

func buildStackNames(rec *spanRecord, all map[uint64]*spanRecord) []string {
	var stack []string
	cur := rec
	for cur != nil {
		stack = append([]string{cur.name}, stack...)
		if cur.parent == 0 {
			break
		}
		cur = all[cur.parent]
	}
	return stack
}

var frameNameToIndex = map[string]map[string]int{} // ctx -> name -> idx

func appendOpenEventLocked(ctx, name string, at int64) {
	if frameNameToIndex[ctx] == nil {
		frameNameToIndex[ctx] = map[string]int{}
	}
	idx, ok := frameNameToIndex[ctx][name]
	if !ok {
		idx = len(frameNameToIndex[ctx])
		frameNameToIndex[ctx][name] = idx
	}
	ev := speedscopeEvent{Type: "O", At: at, Frame: idx}
	if ctx == "tick" {
		state.tickEvents = append(state.tickEvents, ev)
	} else {
		state.frameEvents = append(state.frameEvents, ev)
	}
}

func appendCloseEventLocked(ctx, name string, at int64) {
	idx, ok := frameNameToIndex[ctx][name]
	if !ok {
		return
	}
	ev := speedscopeEvent{Type: "C", At: at, Frame: idx}
	if ctx == "tick" {
		state.tickEvents = append(state.tickEvents, ev)
	} else {
		state.frameEvents = append(state.frameEvents, ev)
	}
}

func exportSessionLocked(endReason string) {
	if state.sessionID == "" {
		return
	}
	dir := filepath.Join(flameGraphsDir(), state.sessionID)
	_ = os.MkdirAll(dir, 0o755)

	writeSpeedscope(dir, "tick", state.tickEvents, frameNameToIndex["tick"])
	writeSpeedscope(dir, "frame", state.frameEvents, frameNameToIndex["frame"])
	writeFolded(dir, "tick", state.tickSpans)
	writeFolded(dir, "frame", state.frameSpans)

	meta := map[string]interface{}{
		"session_id":  state.sessionID,
		"script":      state.scriptName,
		"started_at":  state.sessionStart.Format(time.RFC3339),
		"ended_at":    time.Now().Format(time.RFC3339),
		"end_reason":  endReason,
		"tick_spans":  len(state.tickSpans),
		"frame_spans": len(state.frameSpans),
		"output_dir":  dir,
	}
	b, _ := json.MarshalIndent(meta, "", "  ")
	_ = os.WriteFile(filepath.Join(dir, "session.meta.json"), b, 0o644)
}

func writeSpeedscope(dir, ctx string, events []speedscopeEvent, frameMap map[string]int) {
	frames := make([]string, len(frameMap))
	for name, idx := range frameMap {
		if idx < len(frames) {
			frames[idx] = name
		}
	}
	var startVal, endVal int64
	if len(events) > 0 {
		startVal = events[0].At
		endVal = events[len(events)-1].At
	}
	prof := speedscopeProfile{
		Type:      "https://www.speedscope.app/file-format/schema#evented",
		Name:      ctx,
		Unit:      "nanoseconds",
		StartTime: startVal,
		EndTime:   endVal,
		Events:    events,
		Frames:    frames,
	}
	b, err := json.Marshal(prof)
	if err != nil {
		return
	}
	_ = os.WriteFile(filepath.Join(dir, ctx+".speedscope.json"), b, 0o644)
}

func writeFolded(dir, ctx string, spans []completedSpan) {
	agg := map[string]int64{}
	for _, s := range spans {
		key := strings.Join(s.stack, ";")
		if key == "" {
			key = s.name
		}
		dur := s.endNs - s.startNs
		if dur < 0 {
			dur = 0
		}
		agg[key] += dur
	}
	var lines []string
	for k, v := range agg {
		lines = append(lines, fmt.Sprintf("%s %d", k, v))
	}
	sort.Strings(lines)
	_ = os.WriteFile(filepath.Join(dir, ctx+".folded.txt"), []byte(strings.Join(lines, "\n")), 0o644)
}

func resetSessionLocked() {
	state.sessionID = ""
	state.scriptName = ""
	state.activeCtx = ""
	state.tickOpen = false
	state.frameOpen = false
	state.spans = make(map[uint64]*spanRecord)
	state.openStack = nil
	state.tickSpans = nil
	state.frameSpans = nil
	state.tickEvents = nil
	state.frameEvents = nil
	frameNameToIndex = map[string]map[string]int{}
	profilingStarted = false
	lastActivity = time.Time{}
}

func queryUnescape(r *http.Request, key string) string {
	v := r.URL.Query().Get(key)
	u, err := url.QueryUnescape(v)
	if err != nil {
		return v
	}
	return u
}

func sanitizeFileName(s string) string {
	s = strings.ReplaceAll(s, "\\", "_")
	s = strings.ReplaceAll(s, "/", "_")
	s = strings.ReplaceAll(s, ":", "_")
	if len(s) > 64 {
		s = s[:64]
	}
	return s
}
