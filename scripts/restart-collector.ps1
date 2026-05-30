# Stop anything on 9876 and start timing_collector.exe from run/.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$runDir = Join-Path $root "timing_collector\run"
$exe = Join-Path $runDir "timing_collector.exe"

if (-not (Test-Path $exe)) {
    Write-Warning "restart-collector: missing $exe - run build-fast.bat first"
    exit 1
}

$proc = Get-NetTCPConnection -LocalPort 9876 -ErrorAction SilentlyContinue |
Select-Object -ExpandProperty OwningProcess -Unique
if ($proc) {
    $proc | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 300
}

Start-Process -FilePath $exe -WorkingDirectory $runDir | Out-Null
Start-Sleep -Seconds 1

try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:9876/" -UseBasicParsing -TimeoutSec 4
    Write-Host "[restart-collector] OK http://127.0.0.1:9876/ ($($r.StatusCode))"
}
catch {
    Write-Warning "restart-collector: started but HTTP check failed: $($_.Exception.Message)"
    exit 1
}
