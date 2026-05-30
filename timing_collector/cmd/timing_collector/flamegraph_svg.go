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

type fgRect struct {
	name string
	x    float64
	y    float64
	w    float64
	h    float64
	fill string
	ms   float64
}

func buildFlameTree(spans []completedSpan, rootLabel string) *fgNode {
	if rootLabel == "" {
		rootLabel = "all"
	}
	root := &fgNode{name: "all", children: map[string]*fgNode{}}
	for _, s := range spansForFlamegraph(spans) {
		stack := s.stack
		if len(stack) == 0 {
			stack = []string{s.name}
		}
		stack = append([]string{rootLabel}, stack...)
		dur := spanDurationNsFromBounds(s.startNs, s.endNs)
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

func renderFlamegraphSVG(spans []completedSpan, title string, rootLabel string) (string, error) {
	root := buildFlameTree(spans, rootLabel)
	if root.value <= 0 {
		return "", fmt.Errorf("%s: no duration for SVG flame graph", title)
	}

	const (
		chartX = 0.0
		chartY = 48.0
		chartW = 1400.0
		rowH   = 20.0
		uiH    = 48.0
	)

	var rects []fgRect
	flameCollectRects(&rects, root, chartX, chartY, chartW, 0, float64(root.value), rowH)

	depth := flameDepth(root)
	chartH := float64(depth) * rowH
	svgW := chartW
	svgH := uiH + chartH + 8

	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	b.WriteString(`<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 `)
	b.WriteString(fmt.Sprintf("%.0f %.0f", svgW, svgH))
	b.WriteString(`" preserveAspectRatio="xMinYMin meet">`)
	b.WriteString(`<style>.fg{cursor:pointer}.fg:hover{stroke:#fff;stroke-width:1.5}.fg.dim{opacity:0.15}.fg.hit{stroke:#fff;stroke-width:2;opacity:1}</style>`)

	b.WriteString(`<rect class="bg" width="100%" height="100%" fill="#121212"/>`)
	b.WriteString(`<foreignObject x="8" y="6" width="1384" height="36">`)
	b.WriteString(`<div xmlns="http://www.w3.org/1999/xhtml" style="font:13px Segoe UI,sans-serif;color:#eee;display:flex;gap:8px;align-items:center">`)
	b.WriteString(fmt.Sprintf(`<span style="font-weight:600">%s</span>`, escapeXML(title)))
	b.WriteString(`<input id="search" type="text" placeholder="Search functions…" style="flex:1;padding:4px 8px;background:#222;border:1px solid #555;color:#eee;border-radius:4px"/>`)
	b.WriteString(`<button type="button" id="btnReset" style="padding:4px 12px;background:#333;border:1px solid #666;color:#eee;border-radius:4px;cursor:pointer">Reset zoom</button>`)
	b.WriteString(`</div></foreignObject>`)

	b.WriteString(fmt.Sprintf(`<rect class="bg chart-bg" x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#1a1a1a"/>`, chartX, chartY, chartW, chartH))

	for _, r := range rects {
		if r.w < 1 {
			continue
		}
		b.WriteString(fmt.Sprintf(
			`<rect class="fg" data-name="%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#111" stroke-width="0.5" onclick="zoomfg(event,this)"><title>%s — %.2f ms (%.1f%%)</title></rect>`,
			escapeXML(r.name), r.x, r.y, r.w, r.h-1, r.fill,
			escapeXML(r.name), r.ms, 100*float64(r.ms*1e6)/float64(root.value),
		))
		if r.w > 54 {
			b.WriteString(fmt.Sprintf(
				`<text x="%.2f" y="%.2f" fill="#111" font-family="Segoe UI,sans-serif" font-size="10" pointer-events="none">%s</text>`,
				r.x+3, r.y+13, escapeXML(truncate(r.name, 36)),
			))
		}
	}

	b.WriteString(fgInteractiveScript(svgW, svgH))
	b.WriteString(`</svg>`)
	return b.String(), nil
}

func writeFlamegraphSVG(dir, ctx string, spans []completedSpan, rootLabel string) error {
	if rootLabel == "" {
		rootLabel = ctx
	}
	svg, err := renderFlamegraphSVG(spans, ctx, rootLabel)
	if err != nil {
		return err
	}
	path := filepath.Join(dir, ctx+".svg")
	return os.WriteFile(path, []byte(svg), 0o644)
}

func flameCollectRects(rects *[]fgRect, n *fgNode, x, y, w float64, depth int, total float64, rowH float64) {
	if n.value <= 0 || w < 0.5 {
		return
	}
	minW := w
	if minW < 1 {
		minW = 1
	}
	if n.name != "all" && n.name != "tick" {
		*rects = append(*rects, fgRect{
			name: n.name,
			x:    x,
			y:    y,
			w:    minW,
			h:    rowH,
			fill: flameColor(n.name),
			ms:   float64(n.value) / 1e6,
		})
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
		flameCollectRects(rects, c, cursor, y+rowH, cw, depth+1, total, rowH)
		cursor += cw
	}
}

func fgInteractiveScript(svgW, svgH float64) string {
	return fmt.Sprintf(`<script type="text/javascript"><![CDATA[
(function(){
  var svg = document.documentElement;
  var origVB = "0 0 %.0f %.0f";
  var pad = 4;
  function allFrames(){ return document.querySelectorAll("rect.fg"); }
  function zoomfg(ev, el) {
    if (ev) ev.stopPropagation();
    var x = parseFloat(el.getAttribute("x")) - pad;
    var y = parseFloat(el.getAttribute("y")) - pad;
    var w = parseFloat(el.getAttribute("width")) + pad * 2;
    var h = parseFloat(el.getAttribute("height")) + pad * 2;
    svg.setAttribute("viewBox", x + " " + y + " " + w + " " + h);
  }
  function resetzoom() { svg.setAttribute("viewBox", origVB); clearSearch(); }
  function clearSearch() {
    allFrames().forEach(function(r){ r.classList.remove("dim","hit"); });
    var s = document.getElementById("search");
    if (s) s.value = "";
  }
  function doSearch(q) {
    q = (q || "").toLowerCase();
    allFrames().forEach(function(r) {
      r.classList.remove("hit");
      if (!q) { r.classList.remove("dim"); return; }
      var n = (r.getAttribute("data-name") || "").toLowerCase();
      if (n.indexOf(q) >= 0) { r.classList.remove("dim"); r.classList.add("hit"); }
      else { r.classList.add("dim"); }
    });
  }
  document.querySelectorAll(".chart-bg,.bg").forEach(function(el){
    el.addEventListener("click", function(){ resetzoom(); });
  });
  var btn = document.getElementById("btnReset");
  if (btn) btn.addEventListener("click", function(e){ e.stopPropagation(); resetzoom(); });
  var inp = document.getElementById("search");
  if (inp) inp.addEventListener("input", function(){ doSearch(inp.value); });
  if (inp) inp.addEventListener("keydown", function(e){ if (e.key === "Escape") resetzoom(); });
  window.zoomfg = zoomfg;
  window.resetzoom = resetzoom;
})();
]]></script>`, svgW, svgH)
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

func flameColor(name string) string {
	h := fnv.New32a()
	_, _ = h.Write([]byte(name))
	v := h.Sum32()
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
