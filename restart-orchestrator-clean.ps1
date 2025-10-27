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

# Verify all are killed - retry up to 3 times if needed
$maxRetries = 3
$retryCount = 0
while ($retryCount -lt $maxRetries) {
    $remaining = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
    if (-not $remaining) {
        Write-Host "✅ All old processes terminated successfully" -ForegroundColor Green
        break
    }

    $retryCount++
    Write-Host "⚠️  Warning: $($remaining.Count) PowerShell process(es) still running. Retry $retryCount/$maxRetries..." -ForegroundColor Yellow

    # Kill them harder
    $remaining | ForEach-Object {
        Write-Host "  Force-killing stubborn PID: $($_.Id)" -ForegroundColor Red
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2
}

# Final check
$remaining = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
if ($remaining) {
    Write-Host "❌ ERROR: $($remaining.Count) process(es) could not be killed!" -ForegroundColor Red
    Write-Host "PIDs still running:" -ForegroundColor Red
    $remaining | ForEach-Object { Write-Host "  - PID $($_.Id)" -ForegroundColor Red }
    Write-Host "Manual intervention required. Run: Get-Process powershell | Stop-Process -Force" -ForegroundColor Yellow
    exit 1
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

# Extra safety: Wait 1 second to ensure lock file is gone and filesystem is settled
Write-Host "Waiting for filesystem to settle..." -ForegroundColor Gray
Start-Sleep -Seconds 1

cd $PSScriptRoot
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$PSScriptRoot\run-orchestrator.ps1`"" -WindowStyle Normal

Write-Host "✅ Orchestrator restarted!" -ForegroundColor Green
Write-Host "Check the new PowerShell window for bot activity" -ForegroundColor Yellow
