package main

import (
	"embed"
	"encoding/json"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

//go:embed web/*
var webFS embed.FS

func setAPICORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
}

func registerWebUI(mux *http.ServeMux) {
	sub, _ := fs.Sub(webFS, "web")
	mux.Handle("/", http.FileServer(http.FS(sub)))
	mux.HandleFunc("/api/live", handleAPILive)
	mux.HandleFunc("/api/live/flame.svg", handleAPILiveFlameSVG)
	mux.HandleFunc("/api/live/speedscope.json", handleAPILiveSpeedscope)
	mux.HandleFunc("/api/sessions", handleAPISessions)
	mux.HandleFunc("/api/session/", handleAPISessionRoute)
}

func handleAPISessionRoute(w http.ResponseWriter, r *http.Request) {
	setAPICORS(w)
	w.Header().Set("Access-Control-Allow-Methods", "GET, DELETE, OPTIONS")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/session/")
	path = strings.Trim(path, "/")
	if path == "" || strings.Contains(path, "..") {
		http.NotFound(w, r)
		return
	}

	parts := strings.Split(path, "/")
	id := parts[0]
	if strings.Contains(id, "..") {
		http.NotFound(w, r)
		return
	}

	if len(parts) == 1 {
		if r.Method == http.MethodDelete {
			handleDeleteSession(w, id)
			return
		}
		http.Error(w, "use DELETE to remove session", http.StatusMethodNotAllowed)
		return
	}

	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	file := strings.Join(parts[1:], "/")
	if strings.Contains(file, "..") {
		http.NotFound(w, r)
		return
	}
	fpath := filepath.Join(flameGraphsDir(), id, file)
	data, err := os.ReadFile(fpath)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	switch filepath.Ext(file) {
	case ".svg":
		w.Header().Set("Content-Type", "image/svg+xml")
	case ".json":
		w.Header().Set("Content-Type", "application/json")
	default:
		w.Header().Set("Content-Type", "text/plain")
	}
	_, _ = w.Write(data)
}

func handleDeleteSession(w http.ResponseWriter, sessionID string) {
	dir := filepath.Join(flameGraphsDir(), sessionID)
	if _, err := os.Stat(dir); err != nil {
		http.NotFound(w, nil)
		return
	}
	if err := os.RemoveAll(dir); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"deleted": sessionID})
}

func handleAPILive(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()

	type row struct {
		Stack string `json:"stack"`
		Ns    int64  `json:"ns"`
	}
	type openRow struct {
		Stack string  `json:"stack"`
		Ns    int64   `json:"ns"`
		Ms    float64 `json:"ms"`
	}
	var rows []row
	var openRows []openRow
	totals := map[string]int64{}

	addSpan := func(stack []string, ns int64) {
		if ns <= 0 {
			return
		}
		key := strings.Join(stack, ";")
		if key == "" {
			return
		}
		totals[key] += ns
	}

	now := time.Since(serverStart).Nanoseconds()
	for _, s := range collectLiveTopSpansLocked(now) {
		addSpan(s.stack, s.endNs-s.startNs)
	}

	for _, id := range state.openStack {
		rec := state.spans[id]
		if rec == nil || rec.closed || rec.ctx != "tick" {
			continue
		}
		end := rec.endNs
		if end == 0 {
			end = now
		}
		stack := buildStackNames(rec, state.spans)
		ns := end - rec.startNs
		openRows = append(openRows, openRow{
			Stack: strings.Join(stack, " → "),
			Ns:    ns,
			Ms:    float64(ns) / 1e6,
		})
	}

	for k, v := range totals {
		rows = append(rows, row{Stack: k, Ns: v})
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].Ns > rows[j].Ns })
	if len(rows) > 20 {
		rows = rows[:20]
	}

	events := append([]liveEvent(nil), liveEvents...)
	if len(events) > 80 {
		events = events[len(events)-80:]
	}

	profiles, scopeDefault := liveSpeedscopeMetaLocked()
	resp := map[string]interface{}{
		"active":              state.sessionID != "",
		"session_id":          state.sessionID,
		"script":              state.scriptName,
		"tick_open":           state.tickOpen,
		"frame_open":          state.frameOpen,
		"tick_samples":        state.tickSampleNum,
		"top":                 rows,
		"open":                openRows,
		"events":              events,
		"graph_rev":           liveGraphRev,
		"server_time":         time.Now().Format(time.RFC3339),
		"speedscope_profiles": profiles,
		"speedscope_default":  scopeDefault,
	}
	setAPICORS(w)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func handleAPILiveFlameSVG(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	now := time.Since(serverStart).Nanoseconds()
	spans := collectLiveDisplaySpansLocked(now)
	active := state.sessionID != ""
	rootLabel := liveFlameRootName()
	mu.Unlock()

	if !active || len(spans) == 0 {
		w.Header().Set("Content-Type", "image/svg+xml")
		_, _ = w.Write([]byte(`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="80"><text x="12" y="40" fill="#888" font-family="Segoe UI,sans-serif" font-size="14">Waiting for first tick — play with a profiled script loaded</text></svg>`))
		return
	}

	svg, err := renderFlamegraphBytes(spans, rootLabel, rootLabel)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	setAPICORS(w)
	w.Header().Set("Content-Type", "image/svg+xml")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(svg)
}

func handleAPILiveSpeedscope(w http.ResponseWriter, r *http.Request) {
	setAPICORS(w)
	if r.Method == http.MethodOptions {
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	mu.Lock()
	data, _, _, err := buildLiveSpeedscopeLocked()
	mu.Unlock()
	if err != nil {
		data = waitingSpeedscopeJSON()
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(data)
}

func handleAPISessions(w http.ResponseWriter, _ *http.Request) {
	setAPICORS(w)
	root := flameGraphsDir()
	entries, err := os.ReadDir(root)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	type sess struct {
		ID       string `json:"id"`
		HasTick  bool   `json:"has_tick_svg"`
		HasScope bool   `json:"has_speedscope"`
		ModTime  string `json:"mod_time"`
	}
	list := make([]sess, 0) // must be non-nil so JSON encodes as [] not null
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		id := e.Name()
		dir := filepath.Join(root, id)
		_, errSVG := os.Stat(filepath.Join(dir, "tick.svg"))
		_, errSc := os.Stat(filepath.Join(dir, "tick.speedscope.json"))
		info, _ := e.Info()
		mt := ""
		if info != nil {
			mt = info.ModTime().Format(time.RFC3339)
		}
		list = append(list, sess{
			ID:       id,
			HasTick:  errSVG == nil,
			HasScope: errSc == nil,
			ModTime:  mt,
		})
	}
	sort.Slice(list, func(i, j int) bool { return list[i].ModTime > list[j].ModTime })

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(list)
}

func openViewerForSession(sessionID string) {
	url := "http://" + listenAddr + "/?session=" + sessionID
	tryOpenBrowser(url)
}
