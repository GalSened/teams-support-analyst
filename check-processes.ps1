# Check for orchestrator-v3 processes

Write-Host "Checking for orchestrator-v3 processes..." -ForegroundColor Cyan

# Check for PowerShell processes
$allPwshProcesses = Get-Process | Where-Object {
    $_.ProcessName -eq 'pwsh' -or $_.ProcessName -eq 'powershell'
}

if ($allPwshProcesses) {
    Write-Host "`nFound PowerShell processes:" -ForegroundColor Yellow
    $allPwshProcesses | Select-Object Id, ProcessName, StartTime, CPU | Format-Table
} else {
    Write-Host "No PowerShell processes found." -ForegroundColor Green
}

# Check for Node.js processes (for LocalSearch API)
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue

if ($nodeProcesses) {
    Write-Host "`nFound Node.js processes:" -ForegroundColor Yellow
    $nodeProcesses | Select-Object Id, ProcessName, StartTime, CPU | Format-Table
} else {
    Write-Host "No Node.js processes found." -ForegroundColor Green
}
