# Get specific message by ID
. "$PSScriptRoot\graph-api-helpers.ps1"

$messages = Get-TeamsChatMessages -ChatId '19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2' -Top 10
$targetMsg = $messages | Where-Object { $_.id -eq '1761469258488' }

if ($targetMsg) {
    Write-Host "=== Bot Response (ID: 1761469258488) ===" -ForegroundColor Cyan
    Write-Host "From: $($targetMsg.from.user.displayName)" -ForegroundColor Green
    Write-Host "Time: $($targetMsg.createdDateTime)" -ForegroundColor Gray
    Write-Host "`nFull Content:" -ForegroundColor Cyan
    Write-Host $targetMsg.body.content -ForegroundColor White
} else {
    Write-Host "Message not found in last 10 messages" -ForegroundColor Red
}
