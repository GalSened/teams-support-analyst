# Check orchestrator status
$logFile = "$PSScriptRoot\state\orchestrator.log"

if (Test-Path $logFile) {
    Write-Host "=== Last 20 lines of orchestrator log ===" -ForegroundColor Cyan
    Get-Content $logFile -Tail 20
} else {
    Write-Host "Log file not found!" -ForegroundColor Red
}
