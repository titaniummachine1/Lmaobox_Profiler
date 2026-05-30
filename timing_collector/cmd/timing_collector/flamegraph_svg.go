package main

import (
	"fmt"
	"hash/fnv"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type fgNode struct {
	name     string
	value    int64
	children map[string]*fgNode
}

func buildFlameTree(spans []completedSpan) *fgNode {
	root := &fgNode{name: "tick", children: map[string]*fgNode{}}
	for _, s := range spans {
		stack := s.stack
		if len(stack) == 0 {
			stack = []string{s.name}
		}
		dur := s.endNs - s.startNs
		if dur <= 0 {
			continue
		}
		node := root
		node.value += dur
		for _, part := range stack {
			if node.children[part] == nil {
				node.children[part] = &fgNode{name: part, children: map[string]*fgNode{}}
			}
			node = node.children[part]
			node.value += dur
		}
	}
	return root
}

func writeFlamegraphSVG(dir, ctx string, spans []completedSpan) error {
	root := buildFlameTree(spans)
	if root.value <= 0 {
		return fmt.Errorf("%s: no duration for SVG flame graph", ctx)
	}

	const (
		width  = 1200
		rowH   = 22
		pad    = 8
		header = 28
	)

	depth := flameDepth(root)
	height := header + pad*2 + depth*rowH
	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	b.WriteString(fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">`, width, height, width, height))
	b.WriteString(`<rect width="100%" height="100%" fill="#1a1a1a"/>`)
	b.WriteString(fmt.Sprintf(`<text x="%d" y="20" fill="#eee" font-family="Segoe UI, sans-serif" font-size="14">%s — click/zoom in browser (Rust-style flame graph)</text>`, pad, ctx))

	flameLayout(&b, root, pad, float64(header+pad), float64(width-pad*2), 0, float64(root.value), rowH)

	b.WriteString(`</svg>`)
	path := filepath.Join(dir, ctx+".svg")
	return os.WriteFile(path, []byte(b.String()), 0o644)
}

func flameDepth(n *fgNode) int {
	if len(n.children) == 0 {
		return 1
	}
	max := 0
	for _, c := range n.children {
		d := flameDepth(c)
		if d > max {
			max = d
		}
	}
	return max + 1
}

func flameLayout(b *strings.Builder, n *fgNode, x, y, w float64, depth int, total float64, rowH float64) {
	if n.value <= 0 || w < 1 {
		return
	}
	minW := w
	if minW < 2 {
		minW = 2
	}
	fill := flameColor(n.name)
	label := n.name
	if n.name == "tick" && depth == 0 {
		label = ""
	}
	if label != "" && minW > 40 {
		b.WriteString(fmt.Sprintf(
			`<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#111" stroke-width="0.5" rx="1"><title>%s — %.2f ms</title></rect>`,
			x, y, minW, rowH-1, fill, escapeXML(label), float64(n.value)/1e6,
		))
		if minW > 60 {
			b.WriteString(fmt.Sprintf(
				`<text x="%.2f" y="%.2f" fill="#111" font-family="Segoe UI, sans-serif" font-size="11">%s</text>`,
				x+3, y+14, escapeXML(truncate(label, 32)),
			))
		}
	} else if label != "" {
		b.WriteString(fmt.Sprintf(
			`<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#111" stroke-width="0.5"><title>%s — %.2f ms</title></rect>`,
			x, y, minW, rowH-1, fill, escapeXML(label), float64(n.value)/1e6,
		))
	}

	keys := make([]string, 0, len(n.children))
	for k := range n.children {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	cursor := x
	childTotal := float64(n.value)
	if childTotal <= 0 {
		childTotal = 1
	}
	for _, k := range keys {
		c := n.children[k]
		cw := w * float64(c.value) / childTotal
		flameLayout(b, c, cursor, y+rowH, cw, depth+1, total, rowH)
		cursor += cw
	}
}

func flameColor(name string) string {
	h := fnv.New32a()
	_, _ = h.Write([]byte(name))
	v := h.Sum32()
	// warm palette like classic flamegraph "hot"
	r := 200 + int(v%55)
	g := 80 + int((v>>8)%120)
	b := 20 + int((v>>16)%40)
	return fmt.Sprintf("rgb(%d,%d,%d)", r, g, b)
}

func escapeXML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, `"`, "&quot;")
	return s
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}
