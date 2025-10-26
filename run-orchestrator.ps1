# Simple runner for orchestrator-v3.ps1
# Loads .env and runs the orchestrator

# Change to script directory
Set-Location $PSScriptRoot

# Load .env file
Get-Content .env | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^([^=]+)=(.*)$' -and -not $line.StartsWith('#')) {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim() -replace '^"|"$',''
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}

# Run orchestrator v5 (Human-Like Edition)
& .\orchestrator-v5.ps1
