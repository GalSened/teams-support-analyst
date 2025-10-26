# System Monitoring Dashboard for Teams Support Analyst
# Real-time monitoring of LocalSearch API and Orchestrator

param(
    [int]$RefreshInterval = 5,  # seconds
    [switch]$Continuous
)

$API_URL = "http://localhost:3001"
$LOG_FILE = "./logs/orchestrator.log"

function Get-ColorForStatus {
    param([string]$Status)
    switch ($Status) {
        "ok" { "Green" }
        "healthy" { "Green" }
        "degraded" { "Yellow" }
        "unhealthy" { "Red" }
        default { "Gray" }
    }
}

function Get-APIHealth {
    try {
        $response = Invoke-RestMethod -Uri "$API_URL/health" -Method GET -TimeoutSec 5
        return @{
            Available = $true
            Status = $response.status
            RipgrepInstalled = $response.ripgrep_installed
            RepoCount = $response.repo_count
            Repos = $response.repos
            Timestamp = $response.timestamp
        }
    } catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-RecentLogs {
    param([int]$Lines = 10)

    if (Test-Path $LOG_FILE) {
        return Get-Content $LOG_FILE -Tail $Lines
    }
    return @("No log file found")
}

function Get-ProcessInfo {
    $processes = @()

    # Check for node processes (LocalSearch API)
    $nodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        foreach ($proc in $nodeProcs) {
            $processes += @{
                Name = "node.exe"
                PID = $proc.Id
                Memory = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                CPU = $proc.CPU
            }
        }
    }

    # Check for PowerShell processes (Orchestrator)
    $psProcs = Get-Process -Name "powershell" -ErrorAction SilentlyContinue |
               Where-Object { $_.CommandLine -like "*orchestrator*" }
    if ($psProcs) {
        foreach ($proc in $psProcs) {
            $processes += @{
                Name = "PowerShell (Orchestrator)"
                PID = $proc.Id
                Memory = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                CPU = $proc.CPU
            }
        }
    }

    return $processes
}

function Show-Dashboard {
    Clear-Host

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         Teams Support Analyst - System Monitor Dashboard            ║" -ForegroundColor Cyan
    Write-Host "║                    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # LocalSearch API Status
    Write-Host "📊 LocalSearch API Status" -ForegroundColor White
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $apiHealth = Get-APIHealth
    if ($apiHealth.Available) {
        $statusColor = Get-ColorForStatus $apiHealth.Status
        Write-Host "  Status: " -NoNewline
        Write-Host $apiHealth.Status.ToUpper() -ForegroundColor $statusColor
        Write-Host "  Ripgrep: $(if ($apiHealth.RipgrepInstalled) { '✓ Installed' } else { '✗ Not Found' })" -ForegroundColor $(if ($apiHealth.RipgrepInstalled) { 'Green' } else { 'Red' })
        Write-Host "  Repositories: $($apiHealth.RepoCount)"
        foreach ($repo in $apiHealth.Repos) {
            Write-Host "    • $repo" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Status: " -NoNewline
        Write-Host "OFFLINE" -ForegroundColor Red
        Write-Host "  Error: $($apiHealth.Error)" -ForegroundColor Red
    }
    Write-Host ""

    # Process Information
    Write-Host "⚙️  Running Processes" -ForegroundColor White
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $processes = Get-ProcessInfo
    if ($processes.Count -gt 0) {
        Write-Host "  Process                          PID      Memory (MB)    CPU" -ForegroundColor Yellow
        foreach ($proc in $processes) {
            $procName = $proc.Name.PadRight(28)
            $pid = $proc.PID.ToString().PadRight(8)
            $memory = $proc.Memory.ToString().PadRight(14)
            $cpu = if ($proc.CPU) { [math]::Round($proc.CPU, 2).ToString() } else { "N/A" }
            Write-Host "  $procName $pid $memory $cpu" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No related processes found" -ForegroundColor Yellow
    }
    Write-Host ""

    # Recent Activity
    Write-Host "📝 Recent Orchestrator Activity (Last 10 lines)" -ForegroundColor White
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $recentLogs = Get-RecentLogs -Lines 10
    foreach ($line in $recentLogs) {
        if ($line -match '\[ERROR\]') {
            Write-Host "  $line" -ForegroundColor Red
        } elseif ($line -match '\[SUCCESS\]') {
            Write-Host "  $line" -ForegroundColor Green
        } elseif ($line -match '\[WARN\]') {
            Write-Host "  $line" -ForegroundColor Yellow
        } else {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # System Resources
    Write-Host "💻 System Resources" -ForegroundColor White
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $memory = Get-WmiObject Win32_OperatingSystem
    $memUsedPct = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)

    Write-Host "  CPU Usage: $([math]::Round($cpu, 2))%" -ForegroundColor $(if ($cpu -gt 80) { "Red" } elseif ($cpu -gt 50) { "Yellow" } else { "Green" })
    Write-Host "  Memory Usage: $memUsedPct%" -ForegroundColor $(if ($memUsedPct -gt 80) { "Red" } elseif ($memUsedPct -gt 60) { "Yellow" } else { "Green" })
    Write-Host ""

    # Footer
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    if ($Continuous) {
        Write-Host "  Refreshing every $RefreshInterval seconds... Press Ctrl+C to exit" -ForegroundColor Gray
    } else {
        Write-Host "  Run with -Continuous flag for auto-refresh" -ForegroundColor Gray
    }
    Write-Host ""
}

# Main execution
if ($Continuous) {
    while ($true) {
        Show-Dashboard
        Start-Sleep -Seconds $RefreshInterval
    }
} else {
    Show-Dashboard
}
