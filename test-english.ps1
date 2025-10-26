# Test English message
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Send English test message
$body = @{
    body = @{
        content = "@SupportBot What is the recommended caching strategy for the user API?"
    }
} | ConvertTo-Json -Depth 3

try {
    $token = Get-GraphToken
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    $uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

    Write-Host "✓ English test message sent successfully!" -ForegroundColor Green
    Write-Host "Message ID: $($response.id)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
