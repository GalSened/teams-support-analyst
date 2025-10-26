# LocalSearch API Test Suite
# Tests all API endpoints to verify functionality

param(
    [string]$ApiUrl = "http://localhost:3001"
)

Write-Host "=== LocalSearch API Test Suite ===" -ForegroundColor Cyan
Write-Host "Testing API at: $ApiUrl`n" -ForegroundColor Yellow

$testsPassed = 0
$testsFailed = 0

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [scriptblock]$Validator
    )

    Write-Host "Testing: $Name" -ForegroundColor White -NoNewline

    try {
        $params = @{
            Uri = "$ApiUrl$Path"
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }

        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Compress)
        }

        $response = Invoke-RestMethod @params

        # Run custom validator
        if ($Validator) {
            $validationResult = & $Validator $response
            if ($validationResult -ne $true) {
                throw "Validation failed: $validationResult"
            }
        }

        Write-Host " ✓ PASS" -ForegroundColor Green
        $script:testsPassed++
        return $response
    }
    catch {
        Write-Host " ✗ FAIL" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
        return $null
    }
}

# Test 1: Health Check
Write-Host "`n--- Basic Connectivity ---" -ForegroundColor Cyan
Test-Endpoint -Name "Health check endpoint" -Method "GET" -Path "/health" -Validator {
    param($response)
    if ($response.status -ne "ok") { return "Status is not 'ok'" }
    if (-not $response.ripgrep_installed) { return "Ripgrep not installed" }
    if ($response.repo_count -eq 0) { return "No repositories configured" }
    return $true
}

# Test 2: Root Endpoint
Test-Endpoint -Name "Root endpoint" -Method "GET" -Path "/" -Validator {
    param($response)
    if ($response.name -ne "LocalSearch API") { return "Invalid API name" }
    if (-not $response.endpoints) { return "No endpoints listed" }
    return $true
}

# Test 3: Search with common term
Write-Host "`n--- Search Functionality ---" -ForegroundColor Cyan
$searchResult = Test-Endpoint -Name "Search for 'function'" -Method "POST" -Path "/search" -Body @{
    query = "function"
    max_results = 5
} -Validator {
    param($response)
    if ($response.success -ne $true) { return "Success is not true" }
    if ($response.query -ne "function") { return "Query not echoed correctly" }
    if ($null -eq $response.results) { return "No results array" }
    # Count can be 0 if no matches, that's ok
    return $true
}

if ($searchResult -and $searchResult.count -gt 0) {
    Write-Host "  Found $($searchResult.count) results" -ForegroundColor Gray
    Write-Host "  Sample: $($searchResult.results[0].path):$($searchResult.results[0].line)" -ForegroundColor Gray
}

# Test 4: Search with specific term
Test-Endpoint -Name "Search for 'export'" -Method "POST" -Path "/search" -Body @{
    query = "export"
    max_results = 3
} -Validator {
    param($response)
    if ($response.success -ne $true) { return "Success is not true" }
    return $true
}

# Test 5: Search validation (empty query)
Write-Host "`n--- Input Validation ---" -ForegroundColor Cyan
Test-Endpoint -Name "Reject empty query" -Method "POST" -Path "/search" -Body @{
    query = ""
} -Validator {
    param($response)
    # Should fail with 400, so if we get here, the API didn't validate properly
    return "API accepted empty query (should have rejected)"
}

# Test 6: Search validation (max results)
Test-Endpoint -Name "Respect max_results limit" -Method "POST" -Path "/search" -Body @{
    query = "function"
    max_results = 2
} -Validator {
    param($response)
    if ($response.success -ne $true) { return "Success is not true" }
    if ($response.results.Count -gt 2) { return "Returned more than max_results" }
    return $true
}

# Test 7: File info endpoint (if we have search results)
if ($searchResult -and $searchResult.count -gt 0) {
    Write-Host "`n--- File Operations ---" -ForegroundColor Cyan
    $firstResult = $searchResult.results[0]

    Test-Endpoint -Name "Get file info" -Method "POST" -Path "/file-info" -Body @{
        path = $firstResult.path
    } -Validator {
        param($response)
        if ($response.success -ne $true) { return "Success is not true" }
        if (-not $response.path) { return "No path in response" }
        if (-not $response.exists) { return "File does not exist" }
        return $true
    }

    # Test 8: Read file snippet
    Test-Endpoint -Name "Read file snippet" -Method "POST" -Path "/file" -Body @{
        path = $firstResult.path
        start = [Math]::Max(1, $firstResult.line - 2)
        end = $firstResult.line + 2
    } -Validator {
        param($response)
        if ($response.success -ne $true) { return "Success is not true" }
        if (-not $response.lines) { return "No lines in response" }
        if ($response.lines.Count -eq 0) { return "Empty lines array" }
        return $true
    }
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })

if ($testsFailed -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed. Check errors above." -ForegroundColor Red
    exit 1
}
