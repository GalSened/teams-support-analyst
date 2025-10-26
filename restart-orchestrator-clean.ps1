# Restart Orchestrator - Clean shutdown and restart
Write-Host "🧹 Cleaning up ALL old orchestrator processes..." -ForegroundColor Cyan

# Kill ALL PowerShell processes except the current one
Write-Host "Step 1: Stopping ALL PowerShell instances (except this one)..." -ForegroundColor Yellow
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | ForEach-Object {
    Write-Host "  Stopping PowerShell PID: $($_.Id)" -ForegroundColor Gray
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "Step 2: Waiting for processes to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Verify all are killed
$remaining = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
if ($remaining) {
    Write-Host "⚠️  Warning: $($remaining.Count) PowerShell process(es) still running" -ForegroundColor Red
} else {
    Write-Host "✅ All old processes terminated successfully" -ForegroundColor Green
}

# Remove lock file if it exists
$lockFile = "$PSScriptRoot\state\orchestrator.lock"
if (Test-Path $lockFile) {
    Write-Host "Step 3: Removing process lock file..." -ForegroundColor Yellow
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Lock file removed" -ForegroundColor Green
} else {
    Write-Host "Step 3: No lock file found (OK)" -ForegroundColor Green
}

Write-Host ""
Write-Host "🚀 Starting fresh orchestrator with MCP configuration..." -ForegroundColor Cyan
cd $PSScriptRoot
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$PSScriptRoot\run-orchestrator.ps1`"" -WindowStyle Normal

Write-Host "✅ Orchestrator restarted!" -ForegroundColor Green
Write-Host "Check the new PowerShell window for bot activity" -ForegroundColor Yellow
