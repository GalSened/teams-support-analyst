# Get all bot messages (from "Unknown" sender which indicates bot responses)

$authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

$authData = Get-Content $authFile | ConvertFrom-Json
$token = $authData.token

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Get more messages to capture all bot responses
$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages?`$top=20&`$orderby=createdDateTime desc"

$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

Write-Host "=== All Messages (Recent 20) ===" -ForegroundColor Cyan

$botMessages = @()
$userMessages = @()

$response.value | ForEach-Object {
    $from = if ($_.from.user) { $_.from.user.displayName } else { "Bot" }
    $time = $_.createdDateTime
    $msgId = $_.id
    $content = $_.body.content

    $entry = @{
        Time = $time
        From = $from
        MessageId = $msgId
        Content = $content
        ReplyToId = $_.replyToId
    }

    if ($from -eq "Bot") {
        $botMessages += $entry
    } else {
        $userMessages += $entry
    }
}

Write-Host "`n=== BOT RESPONSES ($($botMessages.Count) total) ===" -ForegroundColor Green
foreach ($msg in $botMessages) {
    Write-Host "`n[Bot Response at $($msg.Time)]" -ForegroundColor Yellow
    Write-Host "Reply to: $($msg.ReplyToId)" -ForegroundColor Gray
    Write-Host "Message ID: $($msg.MessageId)" -ForegroundColor Gray
    Write-Host "`n--- CONTENT ---" -ForegroundColor Cyan
    Write-Host $msg.Content
    Write-Host "`n=============================================" -ForegroundColor DarkGray
}

Write-Host "`n=== USER MESSAGES ($($userMessages.Count) total) ===" -ForegroundColor Magenta
foreach ($msg in $userMessages | Select-Object -First 5) {
    Write-Host "`n[$($msg.Time)] $($msg.From)" -ForegroundColor Yellow
    Write-Host $msg.Content.Substring(0, [Math]::Min(200, $msg.Content.Length))
    Write-Host "..." -ForegroundColor Gray
}
