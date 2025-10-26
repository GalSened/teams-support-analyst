# Send test message to Teams support group chat

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Read the auth token
$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

# Prepare the message
$body = @{
    body = @{
        content = "@SupportBot TEST - What is the recommended caching strategy for the user-backend API?"
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
    Write-Host "✓ Message sent successfully!" -ForegroundColor Green
    Write-Host "Message ID: $($response.id)"
} catch {
    Write-Host "✗ Error sending message:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host $_.Exception.Response
}
