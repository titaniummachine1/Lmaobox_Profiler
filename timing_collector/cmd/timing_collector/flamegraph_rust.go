package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func flamegraphGenExe() string {
	if exe, err := os.Executable(); err == nil {
		p := filepath.Join(filepath.Dir(exe), "flamegraph_gen.exe")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func runFlamegraphGen(foldedPath, svgPath, title string) error {
	gen := flamegraphGenExe()
	if gen == "" {
		return fmt.Errorf("flamegraph_gen.exe not found next to timing_collector.exe")
	}
	cmd := exec.Command(gen, "--input", foldedPath, "--output", svgPath, "--title", title)
	hideSubprocessWindow(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func foldedLinesFromSpans(spans []completedSpan, rootPrefix string) ([]string, error) {
	agg := map[string]int64{}
	for _, s := range spansForFlamegraph(spans) {
		key := strings.Join(s.stack, ";")
		if key == "" {
			key = s.name
		}
		if rootPrefix != "" {
			key = rootPrefix + ";" + key
		}
		agg[key] += spanDurationNsFromBounds(s.startNs, s.endNs)
	}
	if len(agg) == 0 {
		return nil, fmt.Errorf("no folded stack data")
	}
	lines := make([]string, 0, len(agg))
	for k, v := range agg {
		if v > 0 {
			lines = append(lines, fmt.Sprintf("%s %d", k, v))
		}
	}
	if len(lines) == 0 {
		return nil, fmt.Errorf("all span durations are zero")
	}
	return lines, nil
}

func writeFoldedFile(path string, spans []completedSpan, rootPrefix string) error {
	lines, err := foldedLinesFromSpans(spans, rootPrefix)
	if err != nil {
		return err
	}
	return os.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644)
}

func writeFlamegraph(dir, ctx string, spans []completedSpan, rootLabel string) error {
	return writeFlamegraphWithTitle(dir, ctx, spans, rootLabel, "")
}

func writeFlamegraphWithTitle(dir, ctx string, spans []completedSpan, rootLabel, displayTitle string) error {
	if rootLabel == "" {
		rootLabel = ctx
	}
	foldedPath := filepath.Join(dir, ctx+".folded.txt")
	svgPath := filepath.Join(dir, ctx+".svg")
	title := displayTitle
	if title == "" {
		title = ctx
		if rootLabel != "" && rootLabel != ctx {
			title = rootLabel + " — " + ctx
		} else if rootLabel != "" {
			title = rootLabel
		}
	}

	if err := writeFoldedFile(foldedPath, spans, rootLabel); err != nil {
		return err
	}

	if err := runFlamegraphGen(foldedPath, svgPath, title); err != nil {
		log.Printf("[Profiler] inferno SVG failed (%v), using built-in renderer", err)
		return writeFlamegraphSVG(dir, ctx, spans, rootLabel)
	}
	return nil
}

func renderFlamegraphBytes(spans []completedSpan, title, rootLabel string) ([]byte, error) {
	if rootLabel == "" {
		rootLabel = "tick"
	}
	gen := flamegraphGenExe()
	if gen == "" {
		svg, err := renderFlamegraphSVG(spans, title, rootLabel)
		return []byte(svg), err
	}

	tmp, err := os.MkdirTemp("", "profiler-flame-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmp)

	foldedPath := filepath.Join(tmp, "stacks.folded")
	svgPath := filepath.Join(tmp, "out.svg")
	if err := writeFoldedFile(foldedPath, spans, rootLabel); err != nil {
		return nil, err
	}
	if err := runFlamegraphGen(foldedPath, svgPath, title); err != nil {
		log.Printf("[Profiler] live inferno SVG failed (%v), using built-in renderer", err)
		svg, err2 := renderFlamegraphSVG(spans, title, rootLabel)
		return []byte(svg), err2
	}
	return os.ReadFile(svgPath)
}
