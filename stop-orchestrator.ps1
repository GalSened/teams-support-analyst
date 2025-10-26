# Stop orchestrator-v3 processes

Write-Host "Stopping orchestrator-v3..." -ForegroundColor Cyan

# Look for PowerShell processes that might be running orchestrator-v3.ps1
$candidates = Get-Process | Where-Object {
    ($_.ProcessName -eq 'powershell' -or $_.ProcessName -eq 'pwsh') -and
    $_.StartTime -lt (Get-Date).AddHours(-1)  # Running for more than 1 hour
}

if ($candidates) {
    Write-Host "`nFound potential orchestrator processes:" -ForegroundColor Yellow
    foreach ($proc in $candidates) {
        Write-Host "  PID $($proc.Id): Started $($proc.StartTime), CPU: $($proc.CPU)s"
        $confirm = Read-Host "Kill this process? (y/n)"
        if ($confirm -eq 'y') {
            try {
                Stop-Process -Id $proc.Id -Force
                Write-Host "  Killed PID $($proc.Id)" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to kill PID $($proc.Id): $_" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "No long-running PowerShell processes found." -ForegroundColor Green
}

Write-Host "`nChecking logs to confirm shutdown..."
Start-Sleep -Seconds 15

$lastLogLine = Get-Content "C:\Users\gals\teams-support-analyst\logs\orchestrator.log" -Tail 1
Write-Host "Last log line: $lastLogLine"

if ($lastLogLine -match (Get-Date -Format "yyyy-MM-dd HH:mm")) {
    Write-Host "⚠ Orchestrator might still be running (recent log activity)" -ForegroundColor Yellow
} else {
    Write-Host "✓ Orchestrator appears to be stopped" -ForegroundColor Green
}
