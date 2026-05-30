# Re-apply gentler wheel zoom/pan after upgrading bundled speedscope (v1.21.2).
# Upstream: multiplier = 1 + deltaY/100 (zoom), pan = full delta.
$ErrorActionPreference = "Stop"
$js = Join-Path $PSScriptRoot "..\cmd\timing_collector\web\speedscope\speedscope-W5HZ7E66.js"
if (-not (Test-Path $js)) {
    Write-Error "speedscope bundle not found: $js"
}
$c = [IO.File]::ReadAllText($js)
$c2 = $c `
    .Replace("1+r.deltaY/100", "1+r.deltaY/320") `
    .Replace("1+r.deltaY/40", "1+r.deltaY/140") `
    .Replace("this.pan(new C(r.deltaX,r.deltaY))", "this.pan(new C(r.deltaX*.3,r.deltaY*.3))")
if ($c -eq $c2) {
    Write-Warning "patch_speedscope_zoom: patterns not found (already patched or bundle changed)"
    exit 0
}
[IO.File]::WriteAllText($js, $c2)
Write-Host "patched speedscope wheel zoom/pan: $js"
