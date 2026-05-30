# Simulates multi_tick_test-style profiling against a running timing_collector.exe
$base = "http://127.0.0.1:9876"

function Get-Ok($url) {
    try {
        return (Invoke-WebRequest -Uri ($base + $url) -UseBasicParsing).Content.Trim()
    }
    catch {
        Write-Error "FAIL $url : $_"
        exit 1
    }
}

if ((Get-Ok "/version") -ne "2") { Write-Error "collector version not 2"; exit 1 }
$sid = Get-Ok "/session/begin?script=simulate_test"
Write-Host "session=$sid"

for ($t = 1; $t -le 12; $t++) {
    Get-Ok "/tick/begin" | Out-Null
    $cm = Get-Ok "/span/start?name=CreateMove&ctx=tick"
    $sb = Get-Ok "/span/start?name=setupBones&ctx=tick&parent=$cm"
    Start-Sleep -Milliseconds 2
    Get-Ok "/span/end?span_id=$sb" | Out-Null
    $cp = Get-Ok "/span/start?name=cachePlayers&ctx=tick&parent=$cm"
    Start-Sleep -Milliseconds 1
    Get-Ok "/span/end?span_id=$cp" | Out-Null
    Get-Ok "/span/end?span_id=$cm" | Out-Null
    Get-Ok "/tick/end" | Out-Null
    Write-Host "tick $t OK"
}

Get-Ok "/session/end" | Out-Null
Write-Host "export done - open saved session $sid"

$j = Get-Content "c:\gitProjects\profiler\timing_collector\run\flame_graphs\$sid\tick.speedscope.json" -Raw | ConvertFrom-Json
Write-Host "activeProfileIndex=$($j.activeProfileIndex) (want 0)"
Write-Host "profiles: $($j.profiles.name -join ' | ')"
if ($j.profiles.Count -ne 3) {
    Write-Error "expected 3 profiles (merged, average, last), got $($j.profiles.Count)"
    exit 1
}
if ($j.profiles[1].name -ne "Average tick" -or $j.profiles[2].name -ne "Last tick") {
    Write-Error "unexpected profile names"
    exit 1
}
$merged = $j.profiles[0]
Write-Host "merged events=$($merged.events.Count) avg=$($j.profiles[1].name) last=$($j.profiles[2].name)"
if ($merged.events.Count -lt 24) {
    Write-Error "merged timeline too short"
    exit 1
}
Write-Host "OK: 3 speedscope views, merged timeline has all ticks"
