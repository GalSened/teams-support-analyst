# Stop All Orchestrator Instances
Write-Host "Searching for orchestrator processes..." -ForegroundColor Yellow

# Find all PowerShell processes
$allProcesses = Get-Process powershell -ErrorAction SilentlyContinue

if ($null -eq $allProcesses) {
    Write-Host "No PowerShell processes found" -ForegroundColor Green
    exit 0
}

$orchestratorProcesses = @()

foreach ($proc in $allProcesses) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
        if ($cmdLine -like "*orchestrator*") {
            $orchestratorProcesses += [PSCustomObject]@{
                PID = $proc.Id
                StartTime = $proc.StartTime
                CommandLine = $cmdLine
            }
        }
    } catch {
        # Skip if we can't get command line
    }
}

if ($orchestratorProcesses.Count -eq 0) {
    Write-Host "No orchestrator processes found" -ForegroundColor Green
} else {
    Write-Host "Found $($orchestratorProcesses.Count) orchestrator process(es):" -ForegroundColor Red
    $orchestratorProcesses | Format-Table -AutoSize

    Write-Host "`nStopping orchestrator processes..." -ForegroundColor Yellow
    foreach ($proc in $orchestratorProcesses) {
        Stop-Process -Id $proc.PID -Force
        Write-Host "  Stopped PID: $($proc.PID)" -ForegroundColor Green
    }

    Write-Host "`nAll orchestrator processes stopped" -ForegroundColor Green
}
