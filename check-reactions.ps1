# Check message reactions
. "$PSScriptRoot\graph-api-helpers.ps1"

$CHAT_ID = '19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2'
$MESSAGE_ID = '1761540403965'  # One of the messages you added eyes to

$token = Get-GraphToken
$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

# Get message with reactions
$uri = "https://graph.microsoft.com/v1.0/chats/$CHAT_ID/messages/$MESSAGE_ID"
$message = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

Write-Host "`n=== Message Reactions ===" -ForegroundColor Cyan
if ($message.reactions -and $message.reactions.Count -gt 0) {
    foreach ($reaction in $message.reactions) {
        Write-Host "`nReaction Type: $($reaction.reactionType)" -ForegroundColor Yellow
        Write-Host "User: $($reaction.user.user.displayName)"
        Write-Host "Created: $($reaction.createdDateTime)"
    }
} else {
    Write-Host "No reactions found on this message" -ForegroundColor Red
}
