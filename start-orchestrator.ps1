# Startup script for Teams Support Analyst Orchestrator
# Loads .env file and starts orchestrator-v3.ps1 in background

Write-Host "=== Starting Teams Support Analyst Orchestrator ===" -ForegroundColor Cyan

# Change to script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Load .env file
$envFile = ".\.env"
if (Test-Path $envFile) {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Yellow

    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()

        # Skip empty lines and comments
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }

        # Parse KEY=VALUE
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes if present
            $value = $value -replace '^"(.*)"$', '$1'
            $value = $value -replace "^'(.*)'$", '$1'

            # Set environment variable
            Set-Item -Path "env:$key" -Value $value
            Write-Host "  $key = $value" -ForegroundColor Gray
        }
    }

    Write-Host "Environment variables loaded!" -ForegroundColor Green
} else {
    Write-Host "Warning: .env file not found at $envFile" -ForegroundColor Yellow
}

# Verify critical environment variables
$requiredVars = @("TEAMS_CHAT_ID", "LOCALSEARCH_PORT", "BOT_NAME")
$missing = @()

foreach ($var in $requiredVars) {
    if ([string]::IsNullOrWhiteSpace((Get-Item -Path "env:$var" -ErrorAction SilentlyContinue).Value)) {
        $missing += $var
    }
}

if ($missing.Count -gt 0) {
    Write-Host "ERROR: Missing required environment variables:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nEnvironment validated!" -ForegroundColor Green
Write-Host "  TEAMS_CHAT_ID: $env:TEAMS_CHAT_ID"
Write-Host "  BOT_NAME: $env:BOT_NAME"
Write-Host "  LOCALSEARCH_PORT: $env:LOCALSEARCH_PORT"

# Clear old logs
Write-Host "`nClearing old orchestrator.log..." -ForegroundColor Yellow
if (Test-Path ".\logs\orchestrator.log") {
    Clear-Content ".\logs\orchestrator.log"
    Write-Host "Log cleared!" -ForegroundColor Green
}

# Start orchestrator in background
Write-Host "`nStarting orchestrator-v3.ps1 in background..." -ForegroundColor Cyan

$job = Start-Job -ScriptBlock {
    param($scriptPath)
    & $scriptPath
} -ArgumentList "$scriptDir\orchestrator-v3.ps1"

Write-Host "Orchestrator started! Job ID: $($job.Id)" -ForegroundColor Green

# Wait a few seconds and check initial logs
Write-Host "`nWaiting 5 seconds for initialization..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`n=== Initial Log Output ===" -ForegroundColor Cyan
if (Test-Path ".\logs\orchestrator.log") {
    Get-Content ".\logs\orchestrator.log" -Tail 20
} else {
    Write-Host "Log file not created yet..." -ForegroundColor Yellow
}

Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "✓ Orchestrator is running!" -ForegroundColor Green
Write-Host "  Job ID: $($job.Id)" -ForegroundColor Yellow
Write-Host "  Monitor logs: tail -f logs/orchestrator.log" -ForegroundColor Yellow
Write-Host "  Stop orchestrator: Stop-Job $($job.Id); Remove-Job $($job.Id)" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Cyan
