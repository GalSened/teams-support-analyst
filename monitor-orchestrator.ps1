# Monitor orchestrator in real-time
$logPath = "$PSScriptRoot\state\orchestrator.log"

Write-Host "=== LIVE ORCHESTRATOR MONITOR ===" -ForegroundColor Cyan
Write-Host "Watching: $logPath" -ForegroundColor Yellow
Write-Host ""

if (Test-Path $logPath) {
    Write-Host "Last 30 lines of log:" -ForegroundColor Green
    Get-Content $logPath -Tail 30
} else {
    Write-Host "Log file doesn't exist yet - orchestrator may still be starting" -ForegroundColor Yellow
}

Write-Host "`n=== ACTIVE POWERSHELL PROCESSES ===" -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Select-Object Id,StartTime | Format-Table -AutoSize

Write-Host "`n=== LOCAL SEARCH API STATUS ===" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -UseBasicParsing -TimeoutSec 2
    Write-Host "✅ Local Search API is running (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "❌ Local Search API not responding" -ForegroundColor Red
}
