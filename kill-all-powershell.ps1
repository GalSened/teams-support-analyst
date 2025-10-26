# Nuclear option: Kill all PowerShell processes except current one
$currentPID = $PID
Write-Host "Current PID: $currentPID" -ForegroundColor Yellow

Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $currentPID } | ForEach-Object {
    Write-Host "Killing PID: $($_.Id)" -ForegroundColor Red
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "All other PowerShell processes terminated" -ForegroundColor Green
