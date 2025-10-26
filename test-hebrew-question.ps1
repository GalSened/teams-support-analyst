# Send comprehensive test message with Hebrew and edge cases

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Read the auth token
$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

# Test message with Hebrew and real scenario
$testMessage = @"
@SupportBot - שלום! I'm investigating an issue where getUserInfo returns null for user yehudap (ID: 270206df-f2a5-41af-a5b0-08de0cabd326).

The user was created successfully on 16-Oct-2025 15:02:05 by systemadmin@comda.co.il, but when the signer (dbb0e2bf-f817-41ac-3596-08de0fc01c4f) tries to view document collection "21b69fc9-638b-4664-1d84-08de0fc01c41" (בדיקה - תמיכה), getUserInfo returns null.

Why would getUserInfo fail after successful user creation? Is this a caching issue, authentication problem, or database query timing issue?
"@

# Prepare the message
$body = @{
    body = @{
        content = $testMessage
    }
} | ConvertTo-Json -Depth 3

# Send the message
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    Write-Host "✓ Comprehensive test message sent!" -ForegroundColor Green
    Write-Host "Message includes:" -ForegroundColor Yellow
    Write-Host "  - Hebrew text (בדיקה - תמיכה)" -ForegroundColor Gray
    Write-Host "  - Real user IDs and document IDs from logs" -ForegroundColor Gray
    Write-Host "  - Complex technical scenario" -ForegroundColor Gray
    Write-Host "  - Edge case: null return after successful creation" -ForegroundColor Gray
    Write-Host "`nMessage ID: $($response.id)" -ForegroundColor Cyan
    Write-Host "`nMonitor orchestrator logs to see analysis in action!" -ForegroundColor Yellow
} catch {
    Write-Host "✗ Error sending message:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
