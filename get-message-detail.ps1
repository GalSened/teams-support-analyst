# Get full message details

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$messageId = "1761201301745"  # Latest response

$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages/$messageId"

$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

Write-Host "=== Full Message Content ===" -ForegroundColor Cyan
Write-Host "From: $($response.from.user.displayName)" -ForegroundColor Yellow
Write-Host "Time: $($response.createdDateTime)" -ForegroundColor Gray
Write-Host "`n--- CONTENT ---" -ForegroundColor Green
Write-Host $response.body.content
