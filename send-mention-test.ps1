# Send test message with @SupportBot mention

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Read the auth token
$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

# Prepare the message with @mention
$body = @{
    body = @{
        content = "@SupportBot - Can you help me understand why getUserInfo returns null sometimes?"
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
    Write-Host "✓ Test message sent with @mention!" -ForegroundColor Green
    Write-Host "Message ID: $($response.id)"
} catch {
    Write-Host "✗ Error sending message:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
