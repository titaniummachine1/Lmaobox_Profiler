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
	tickSpans       []completedSpan
	tickSpanBatches [][]completedSpan // one leaf batch per completed tick (flame average/last)
	frameSpans      []completedSpan

	// Speedscope event buffers per context (reset each tick/frame end export slice append)
	tickEvents  []speedscopeEvent
	frameEvents []speedscopeEvent

	tickEventsStart  int                        // tickEvents index at last tick/begin
	tickSampleNum    int                        // exported tick counter
	tickProfiles     []speedscopeEventedProfile // one speedscope profile per EndTick
	tickRootBoundary string                     // top-level span name for auto tick rollover
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
	Frame int    `json:"frame"` // must not use omitempty — frame index 0 is valid
}

type speedscopeFrame struct {
	Name string `json:"name"`
}

type speedscopeEventedProfile struct {
	Type       string            `json:"type"`
	Name       string            `json:"name"`
	Unit       string            `json:"unit"`
	StartValue int64             `json:"startValue"`
	EndValue   int64             `json:"endValue"`
	Events     []speedscopeEvent `json:"events"`
}

type speedscopeFile struct {
	Schema string `json:"$schema"`
	Shared struct {
		Frames []speedscopeFrame `json:"frames"`
	} `json:"shared"`
	Profiles           []speedscopeEventedProfile `json:"profiles"`
	ActiveProfileIndex int                        `json:"activeProfileIndex"`
	Exporter           string                     `json:"exporter,omitempty"`
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
	mux.HandleFunc("/version", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, "2")
	})
	mux.HandleFunc("/session/begin", handleSessionBegin)
	mux.HandleFunc("/session/end", handleSessionEnd)
	mux.HandleFunc("/tick/begin", handleTickBegin)
	mux.HandleFunc("/tick/end", handleTickEnd)
	mux.HandleFunc("/frame/begin", handleFrameBegin)
	mux.HandleFunc("/frame/end", handleFrameEnd)
	mux.HandleFunc("/span/start", handleSpanStart)
	mux.HandleFunc("/span/end", handleSpanEnd)
	mux.HandleFunc("/span/report", handleSpanReport)
	registerWebUI(mux)

	startIdleWatcher()

	printStartupBanner(outDir)

	freeListenAddr(listenAddr)
	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		freeListenAddr(listenAddr)
		ln, err = net.Listen("tcp", listenAddr)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "timing_collector: cannot listen on %s: %v\n", listenAddr, err)
		fmt.Fprintf(os.Stderr, "Close the other program using port 9876, then run timing_collector.exe again.\n")
		waitBeforeExit()
		os.Exit(1)
	}

	log.Printf("timing_collector on http://%s (flame_graphs: %s)", listenAddr, outDir)
	log.Fatal(http.Serve(ln, mux))
}

func printStartupBanner(outDir string) {
	fmt.Println("============================================================")
	fmt.Println(" Lmaobox Profiler — timing_collector.exe")
	fmt.Println("============================================================")
	fmt.Printf("  Viewer: http://%s/  (live + saved flame graphs)\n", listenAddr)
	fmt.Printf("  Files:  %s\\<session_id>\\tick.svg\n", outDir)
	if flamegraphGenExe() != "" {
		fmt.Println("  SVG:    inferno (flamegraph_gen.exe — cargo-flamegraph quality)")
	} else {
		fmt.Println("  SVG:    built-in renderer (run build.bat with Rust for inferno SVG)")
	}
	fmt.Println()
	fmt.Println("  1. Copy Profiler.lua to %LOCALAPPDATA%\\lua\\")
	fmt.Println("  2. In TF2: lua_load simple_test  (or your script)")
	fmt.Println("  3. Browser opens on export — or use speedscope link in viewer")
	fmt.Println()
	fmt.Println("  Leave this window open while you play.")
	fmt.Println("============================================================")
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
					if err := endSessionLocked("idle_timeout"); err != nil {
						log.Printf("ERROR session %s idle export: %v", state.sessionID, err)
					}
				}
			}
			mu.Unlock()
		}
	}()
}

// endSessionLocked exports and clears the active session (same outcome as /session/end).
func endSessionLocked(reason string) error {
	if state.sessionID == "" {
		return nil
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

	exportErr := exportSessionLocked(reason)
	resetSessionLocked()
	if exportErr != nil {
		log.Printf("ERROR session %s ended (%s): %v", sid, reason, exportErr)
		return exportErr
	}
	log.Printf("session %s OK — flame graph: flame_graphs/%s/tick.speedscope.json", sid, sid)
	return nil
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
		_ = endSessionLocked("session_begin")
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
	state.tickSpanBatches = nil
	state.frameSpans = nil
	state.tickEvents = nil
	state.frameEvents = nil
	state.tickEventsStart = 0
	state.tickSampleNum = 0
	state.tickProfiles = nil
	resetTickBoundaryLocked()
	frameNameToIndex = map[string]map[string]int{}
	profilingStarted = false
	lastActivity = time.Time{}
	clearLiveEvents()
	pushLiveEvent("session", fmt.Sprintf("Session started — %s", script))

	fmt.Fprintf(w, "%s", state.sessionID)
}

func handleSessionEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()

	if state.sessionID == "" {
		fmt.Fprint(w, "0")
		return
	}
	if err := endSessionLocked("api"); err != nil {
		fmt.Fprintf(w, "ERR:%s", err.Error())
		return
	}
	fmt.Fprint(w, "OK")
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
	state.tickEventsStart = len(state.tickEvents)
	resetTickBoundaryLocked()
	pushLiveEvent("tick", fmt.Sprintf("Tick %d begin", state.tickSampleNum+1))
	fmt.Fprint(w, "0")
}

func captureTickProfileLocked() {
	start := state.tickEventsStart
	end := len(state.tickEvents)
	if end <= start {
		return
	}
	chunk := append([]speedscopeEvent(nil), state.tickEvents[start:end]...)
	chunk = rebaseEvents(chunk)
	if len(chunk) < 2 {
		return
	}
	state.tickSampleNum++
	name := fmt.Sprintf("tick %d", state.tickSampleNum)
	startVal := chunk[0].At
	endVal := chunk[len(chunk)-1].At
	if endVal <= startVal {
		return
	}
	state.tickProfiles = append(state.tickProfiles, speedscopeEventedProfile{
		Type:       "evented",
		Name:       name,
		Unit:       "nanoseconds",
		StartValue: startVal,
		EndValue:   endVal,
		Events:     chunk,
	})
}

func handleTickEnd(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()
	if !state.tickOpen {
		fmt.Fprint(w, "-1")
		return
	}
	captureTickProfileLocked()
	flushCtxSpansLocked("tick")
	state.tickOpen = false
	if state.activeCtx == "tick" {
		state.activeCtx = ""
	}
	resetTickBoundaryLocked()
	pushLiveEvent("tick", fmt.Sprintf("Tick %d end", state.tickSampleNum))
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
	pushLiveEvent("frame", "Frame begin")
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
	pushLiveEvent("frame", "Frame end")
	fmt.Fprint(w, "0")
}

func handleSpanStart(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()
	markProfilingActivity()

	if state.sessionID == "" {
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
	if ctx == "" {
		fmt.Fprint(w, "-1")
		return
	}
	if state.activeCtx == "" {
		state.activeCtx = ctx
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

	if ctx == "tick" && parent == 0 {
		maybeBeginTickOnRootSpanLocked(name)
	}

	appendOpenEventLocked(ctx, name, startNs)
	pushLiveEvent("open", fmt.Sprintf("▶ %s", spanStackLabel(rec)))

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

	dur := endNs - rec.startNs
	pushLiveEvent("close", fmt.Sprintf("■ %s — %.3f ms", spanStackLabel(rec), float64(dur)/1e6))
	fmt.Fprintf(w, "%d", dur)
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

	if ctx == "tick" {
		if state.activeCtx == "" {
			state.activeCtx = "tick"
		}
		maybeBeginTickOnReportRootLocked(tickRootFromStack(stack, name))
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
	pushLiveEvent("close", fmt.Sprintf("■ %s — %.3f ms", strings.Join(stack, " → "), float64(durNs)/1e6))

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
	ids := collectSpanIDs(state.spans)

	// Pass 1: close any still-open spans (parents first by ID order is fine here)
	for _, id := range ids {
		rec := state.spans[id]
		if rec == nil || rec.ctx != ctx {
			continue
		}
		if !rec.closed {
			rec.endNs = now
			rec.closed = true
			appendCloseEventLocked(ctx, rec.name, now)
		}
	}

	// Pass 2: build full stacks while ALL parents are still in the map
	var completed []completedSpan
	for _, id := range ids {
		rec := state.spans[id]
		if rec == nil || rec.ctx != ctx {
			continue
		}
		stack := buildStackNames(rec, state.spans)
		completed = append(completed, completedSpan{
			name:    rec.name,
			ctx:     rec.ctx,
			startNs: rec.startNs,
			endNs:   rec.endNs,
			stack:   stack,
		})
	}

	// Pass 3: remove all processed spans at once
	for _, id := range ids {
		if rec := state.spans[id]; rec != nil && rec.ctx == ctx {
			delete(state.spans, id)
		}
	}
	state.openStack = nil

	if ctx == "tick" {
		state.tickSpans = append(state.tickSpans, completed...)
		state.tickSpanBatches = append(state.tickSpanBatches, spansForFlamegraph(completed))
		setLastTickLiveSpans(spansForFlamegraph(completed))
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

func exportSessionLocked(endReason string) error {
	if state.sessionID == "" {
		return fmt.Errorf("no active session")
	}

	if state.tickOpen {
		captureTickProfileLocked()
	}

	tickN := len(state.tickSpanBatches)
	frameN := len(state.frameSpans)
	if tickN == 0 && frameN == 0 {
		return fmt.Errorf(
			"no profiling data received. Lua must call BeginSession, BeginTick, Begin/End (span/start+span/end), EndTick, EndSession while timing_collector.exe is running",
		)
	}

	dir := filepath.Join(flameGraphsDir(), state.sessionID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("cannot create output folder: %w", err)
	}

	var wrote bool
	exportID := state.sessionID
	if tickN > 0 {
		if err := writeSpeedscopeTick(dir, state.tickEvents, frameNameToIndex["tick"], state.tickProfiles); err != nil {
			writeSessionErrorFile(dir, endReason, err)
			return err
		}
		if err := writeFlamegraphViews(dir, state.tickSpanBatches, state.scriptName); err != nil {
			return err
		}
		wrote = true
	}
	if frameN > 0 {
		if err := writeSpeedscope(dir, "frame", state.frameEvents, frameNameToIndex["frame"]); err != nil {
			writeSessionErrorFile(dir, endReason, err)
			return err
		}
		if err := writeFlamegraph(dir, "frame", state.frameSpans, state.scriptName); err != nil {
			return err
		}
		wrote = true
	}

	if !wrote {
		err := fmt.Errorf("internal error: span counts tick=%d frame=%d but nothing exported", tickN, frameN)
		writeSessionErrorFile(dir, endReason, err)
		return err
	}

	_ = endReason
	go openViewerForSession(exportID)
	return nil
}

func writeSessionErrorFile(dir, reason string, err error) {
	msg := fmt.Sprintf("Profiler export FAILED (%s)\n\n%s\n", reason, err.Error())
	_ = os.WriteFile(filepath.Join(dir, "session.error.txt"), []byte(msg), 0o644)
}

// compressEventTimeline caps idle gaps between sampled ticks so speedscope Time Order
// is not mostly empty space (Lua samples ~1 tick/s; wall-clock gaps can be seconds).
func compressEventTimeline(events []speedscopeEvent) []speedscopeEvent {
	if len(events) <= 1 {
		return events
	}
	const maxGapNs = int64(2_000_000) // 2ms visual gap between distant event groups

	out := make([]speedscopeEvent, len(events))
	out[0] = speedscopeEvent{Type: events[0].Type, At: 0, Frame: events[0].Frame}
	cursor := int64(0)
	for i := 1; i < len(events); i++ {
		gap := events[i].At - events[i-1].At
		if gap > maxGapNs {
			gap = maxGapNs
		}
		if gap < 0 {
			gap = 0
		}
		cursor += gap
		out[i] = speedscopeEvent{Type: events[i].Type, At: cursor, Frame: events[i].Frame}
	}
	return out
}

func rebaseEvents(events []speedscopeEvent) []speedscopeEvent {
	if len(events) == 0 {
		return events
	}
	base := events[0].At
	out := make([]speedscopeEvent, len(events))
	for i, e := range events {
		out[i] = speedscopeEvent{Type: e.Type, At: e.At - base, Frame: e.Frame}
	}
	return out
}

func writeSpeedscopeTick(dir string, allEvents []speedscopeEvent, frameMap map[string]int, perTick []speedscopeEventedProfile) error {
	if len(allEvents) == 0 {
		return fmt.Errorf("tick: no speedscope events")
	}
	if len(frameMap) == 0 {
		return fmt.Errorf("tick: no frame names")
	}

	profiles, err := buildSpeedscopeProfiles(perTick, allEvents)
	if err != nil {
		return fmt.Errorf("tick: %w", err)
	}
	active := 0

	file, err := buildSpeedscopeFile(frameMap, profiles, active)
	if err != nil {
		return err
	}
	b, err := json.Marshal(file)
	if err != nil {
		return err
	}
	path := filepath.Join(dir, "tick.speedscope.json")
	if err := os.WriteFile(path, b, 0o644); err != nil {
		return err
	}

	type meta struct {
		Profiles []string `json:"profiles"`
		Default  int      `json:"default_index"`
	}
	names := make([]string, len(profiles))
	for i, p := range profiles {
		names[i] = p.Name
	}
	mb, _ := json.MarshalIndent(meta{Profiles: names, Default: active}, "", "  ")
	_ = os.WriteFile(filepath.Join(dir, "tick.meta.json"), mb, 0o644)
	return nil
}

func writeSpeedscope(dir, ctx string, events []speedscopeEvent, frameMap map[string]int) error {
	if len(events) == 0 {
		return fmt.Errorf("%s: no speedscope events (spans never reached collector)", ctx)
	}
	events = compressEventTimeline(events)
	startVal := events[0].At
	endVal := events[len(events)-1].At
	if endVal <= startVal {
		return fmt.Errorf("%s: profile has zero duration (corrupt or empty)", ctx)
	}
	profiles := []speedscopeEventedProfile{{
		Type:       "evented",
		Name:       ctx,
		Unit:       "nanoseconds",
		StartValue: startVal,
		EndValue:   endVal,
		Events:     events,
	}}
	file, err := buildSpeedscopeFile(frameMap, profiles, 0)
	if err != nil {
		return err
	}
	b, err := json.Marshal(file)
	if err != nil {
		return fmt.Errorf("%s: encode speedscope: %w", ctx, err)
	}
	path := filepath.Join(dir, ctx+".speedscope.json")
	return os.WriteFile(path, b, 0o644)
}

func buildSpeedscopeFile(frameMap map[string]int, profiles []speedscopeEventedProfile, active int) (speedscopeFile, error) {
	maxIdx := -1
	for _, idx := range frameMap {
		if idx > maxIdx {
			maxIdx = idx
		}
	}
	sharedFrames := make([]speedscopeFrame, maxIdx+1)
	for name, idx := range frameMap {
		if idx >= 0 && idx < len(sharedFrames) {
			sharedFrames[idx] = speedscopeFrame{Name: name}
		}
	}
	for i, f := range sharedFrames {
		if f.Name == "" {
			return speedscopeFile{}, fmt.Errorf("missing frame name at index %d", i)
		}
	}
	if active < 0 || active >= len(profiles) {
		active = 0
	}
	file := speedscopeFile{
		Schema:             "https://www.speedscope.app/file-format-schema.json",
		ActiveProfileIndex: active,
		Exporter:           "timing_collector",
	}
	file.Shared.Frames = sharedFrames
	file.Profiles = profiles
	return file, nil
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
	state.tickSpanBatches = nil
	state.frameSpans = nil
	state.tickEvents = nil
	state.frameEvents = nil
	state.tickEventsStart = 0
	state.tickSampleNum = 0
	state.tickProfiles = nil
	resetTickBoundaryLocked()
	frameNameToIndex = map[string]map[string]int{}
	profilingStarted = false
	lastActivity = time.Time{}
	clearLiveEvents()
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
