# Check recent Teams messages

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages?`$top=10&`$orderby=createdDateTime desc"

$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

Write-Host "=== Recent Teams Messages ===" -ForegroundColor Cyan
$response.value | Select-Object -First 10 | ForEach-Object {
    $from = if ($_.from.user) { $_.from.user.displayName } else { "Unknown" }
    $time = $_.createdDateTime
    $msgId = $_.id
    $preview = $_.body.content.Substring(0, [Math]::Min(150, $_.body.content.Length))

    $color = if ($from -eq "Unknown") { "Yellow" } else { "White" }

    Write-Host "`n[$time]" -ForegroundColor Gray
    Write-Host "From: $from (ID: $msgId)" -ForegroundColor $color
    Write-Host "Preview: $preview" -ForegroundColor Gray
    Write-Host "---" -ForegroundColor DarkGray
}
