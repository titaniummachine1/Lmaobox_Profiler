package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const timelinePxPerMs = 3.0
const timelineMinChartW = 1400.0
const timelineMaxChartW = 800000.0

type timelineSegment struct {
	from, to int64
	frames   []int
}

func frameNamesFromMap(frameMap map[string]int) []string {
	maxIdx := -1
	for _, idx := range frameMap {
		if idx > maxIdx {
			maxIdx = idx
		}
	}
	if maxIdx < 0 {
		return nil
	}
	names := make([]string, maxIdx+1)
	for name, idx := range frameMap {
		if idx >= 0 && idx <= maxIdx {
			names[idx] = name
		}
	}
	for i := range names {
		if names[i] == "" {
			names[i] = fmt.Sprintf("frame%d", i)
		}
	}
	return names
}

func buildTimelineSegments(events []speedscopeEvent) []timelineSegment {
	type openRec struct {
		frame int
	}
	var stack []openRec
	var out []timelineSegment
	cursor := events[0].At

	emit := func(from, to int64) {
		if to <= from || len(stack) == 0 {
			return
		}
		frames := make([]int, len(stack))
		for i, o := range stack {
			frames[i] = o.frame
		}
		out = append(out, timelineSegment{from: from, to: to, frames: frames})
	}

	for _, e := range events {
		if e.At > cursor {
			emit(cursor, e.At)
		}
		if e.Type == "O" {
			stack = append(stack, openRec{frame: e.Frame})
			continue
		}
		for j := len(stack) - 1; j >= 0; j-- {
			if stack[j].frame != e.Frame {
				continue
			}
			stack = stack[:j]
			break
		}
		cursor = e.At
	}
	return out
}

func timelineChartWidth(durationNs int64) float64 {
	if durationNs <= 0 {
		return timelineMinChartW
	}
	w := float64(durationNs) / 1e6 * timelinePxPerMs
	if w < timelineMinChartW {
		return timelineMinChartW
	}
	if w > timelineMaxChartW {
		return timelineMaxChartW
	}
	return w
}

func timelineRectsFromEvents(events []speedscopeEvent, frameNames []string, chartX, chartY, chartW, rowH float64) ([]fgRect, int64) {
	if len(events) < 2 || len(frameNames) == 0 {
		return nil, 0
	}
	start := events[0].At
	end := events[len(events)-1].At
	duration := end - start
	if duration <= 0 {
		return nil, 0
	}

	segments := buildTimelineSegments(events)
	var rects []fgRect
	for _, seg := range segments {
		segW := float64(seg.to-seg.from) / float64(duration) * chartW
		if segW < 0.25 {
			continue
		}
		x := chartX + float64(seg.from-start)/float64(duration)*chartW
		for depth, frameIdx := range seg.frames {
			if frameIdx < 0 || frameIdx >= len(frameNames) {
				continue
			}
			name := frameNames[frameIdx]
			rects = append(rects, fgRect{
				name: name,
				x:    x,
				y:    chartY + float64(depth)*rowH,
				w:    segW,
				h:    rowH,
				fill: flameColor(name),
				ms:   float64(seg.to-seg.from) / 1e6,
			})
		}
	}
	return rects, duration
}

func renderTimelineFlamegraphSVG(events []speedscopeEvent, frameMap map[string]int, title, rootLabel string, tickStarts []int64) (string, error) {
	frameNames := frameNamesFromMap(frameMap)
	if len(frameNames) == 0 {
		return "", fmt.Errorf("timeline flame: no frames")
	}
	if len(events) < 2 {
		return "", fmt.Errorf("timeline flame: need events")
	}

	const (
		chartX = 0.0
		chartY = 48.0
		rowH   = 20.0
		uiH    = 48.0
	)

	chartW := timelineChartWidth(events[len(events)-1].At - events[0].At)
	rects, duration := timelineRectsFromEvents(events, frameNames, chartX, chartY, chartW, rowH)
	if len(rects) == 0 {
		return "", fmt.Errorf("timeline flame: no rects")
	}

	depth := 1
	for _, r := range rects {
		d := int((r.y-chartY)/rowH) + 1
		if d > depth {
			depth = d
		}
	}
	chartH := float64(depth) * rowH
	svgW := chartW
	svgH := uiH + chartH + 8

	start := events[0].At
	end := events[len(events)-1].At

	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	b.WriteString(`<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 `)
	b.WriteString(fmt.Sprintf("%.0f %.0f", svgW, svgH))
	b.WriteString(`" preserveAspectRatio="xMinYMin meet">`)
	b.WriteString(`<style>.fg{cursor:pointer}.fg:hover{stroke:#fff;stroke-width:1.5}.fg.dim{opacity:0.15}.fg.hit{stroke:#fff;stroke-width:2;opacity:1}.tick-mark{pointer-events:none}</style>`)

	b.WriteString(`<rect class="bg" width="100%" height="100%" fill="#121212"/>`)
	b.WriteString(`<foreignObject x="8" y="6" width="600" height="36">`)
	b.WriteString(`<div xmlns="http://www.w3.org/1999/xhtml" style="font:13px Segoe UI,sans-serif;color:#eee;display:flex;gap:8px;align-items:center">`)
	b.WriteString(fmt.Sprintf(`<span style="font-weight:600">%s</span>`, escapeXML(title)))
	b.WriteString(`<span style="color:#888;font-size:11px">scroll/zoom · drag chart</span>`)
	b.WriteString(`<input id="search" type="text" placeholder="Search…" style="width:180px;padding:4px 8px;background:#222;border:1px solid #555;color:#eee;border-radius:4px"/>`)
	b.WriteString(`<button type="button" id="btnReset" style="padding:4px 12px;background:#333;border:1px solid #666;color:#eee;border-radius:4px;cursor:pointer">Reset</button>`)
	b.WriteString(`</div></foreignObject>`)

	b.WriteString(fmt.Sprintf(`<rect class="bg chart-bg" x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#1a1a1a"/>`, chartX, chartY, chartW, chartH))

	if duration > 0 {
		for _, tickAt := range tickStarts {
			if tickAt < start || tickAt > end {
				continue
			}
			x := chartX + float64(tickAt-start)/float64(duration)*chartW
			b.WriteString(fmt.Sprintf(
				`<line class="tick-mark" x1="%.2f" y1="%.1f" x2="%.2f" y2="%.1f" stroke="#3a3a3a" stroke-width="1"/>`,
				x, chartY, x, chartY+chartH,
			))
		}
	}

	for _, r := range rects {
		if r.w < 0.25 {
			continue
		}
		pct := 100 * float64(r.ms*1e6) / float64(duration)
		b.WriteString(fmt.Sprintf(
			`<rect class="fg" data-name="%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#111" stroke-width="0.5" onclick="zoomfg(event,this)"><title>%s — %.3f ms (%.2f%% of session)</title></rect>`,
			escapeXML(r.name), r.x, r.y, r.w, r.h-1, r.fill,
			escapeXML(r.name), r.ms, pct,
		))
		if r.w > 48 {
			b.WriteString(fmt.Sprintf(
				`<text x="%.2f" y="%.2f" fill="#111" font-family="Segoe UI,sans-serif" font-size="9" pointer-events="none">%s</text>`,
				r.x+2, r.y+12, escapeXML(truncate(r.name, 28)),
			))
		}
	}

	b.WriteString(fgInteractiveScript(svgW, svgH))
	b.WriteString(`</svg>`)
	return b.String(), nil
}

func writeTimelineFlamegraph(dir, ctx string, perTick []speedscopeEventedProfile, frameMap map[string]int, title string) error {
	events, _, _, tickStarts, err := mergeTickProfiles(perTick)
	if err != nil {
		return err
	}
	svg, err := renderTimelineFlamegraphSVG(events, frameMap, title, "", tickStarts)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, ctx+".svg"), []byte(svg), 0o644)
}

func renderTimelineFlamegraphBytes(perTick []speedscopeEventedProfile, frameMap map[string]int, title string) ([]byte, error) {
	events, _, _, tickStarts, err := mergeTickProfiles(perTick)
	if err != nil {
		return nil, err
	}
	svg, err := renderTimelineFlamegraphSVG(events, frameMap, title, "", tickStarts)
	if err != nil {
		return nil, err
	}
	return []byte(svg), nil
}
