# View full most recent message
. "$PSScriptRoot\graph-api-helpers.ps1"

$messages = Get-TeamsChatMessages -ChatId '19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2' -Top 1

Write-Host "=== Most Recent Message ===" -ForegroundColor Cyan
$msg = $messages[0]
Write-Host "From: $($msg.from.user.displayName)" -ForegroundColor Green
Write-Host "Time: $($msg.createdDateTime)" -ForegroundColor Gray
Write-Host "`nFull Content:" -ForegroundColor Cyan
Write-Host $msg.body.content -ForegroundColor White
