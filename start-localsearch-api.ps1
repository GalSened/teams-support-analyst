# Start LocalSearch API with environment variables
# This script loads the .env file and starts the LocalSearch API

Write-Host "=== Starting LocalSearch API ===" -ForegroundColor Cyan

# Load .env file
$envFile = "$PSScriptRoot\.env"
if (Test-Path $envFile) {
    Write-Host "Loading environment from .env..." -ForegroundColor Yellow
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            # Remove quotes if present
            $value = $value -replace '^[''"]|[''"]$'
            Set-Item -Path "env:$name" -Value $value
            Write-Host "  Set $name" -ForegroundColor Gray
        }
    }
    Write-Host "Environment loaded!" -ForegroundColor Green
} else {
    Write-Host "ERROR: .env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Verify required variables
if ([string]::IsNullOrWhiteSpace($env:REPO_ROOTS)) {
    Write-Host "ERROR: REPO_ROOTS not set in .env" -ForegroundColor Red
    exit 1
}

# Start the API
Write-Host "`nStarting LocalSearch API on port $($env:LOCALSEARCH_PORT)..." -ForegroundColor Cyan
Write-Host "Monitoring repositories:" -ForegroundColor Yellow
$env:REPO_ROOTS -split ';' | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Gray
}
Write-Host ""

Set-Location "$PSScriptRoot\local-search-api"
npm start
