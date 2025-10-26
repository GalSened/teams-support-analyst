. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

Write-Host "Fetching latest 10 messages..." -ForegroundColor Cyan

$messages = Get-TeamsChatMessages -ChatId $chatId -Top 10

foreach ($msg in $messages) {
    Write-Host "`n=== MESSAGE ID: $($msg.id) ===" -ForegroundColor Cyan
    Write-Host "FROM: $($msg.from.user.displayName)" -ForegroundColor Yellow
    Write-Host "CONTENT:" -ForegroundColor Green
    Write-Host $msg.body.content
    Write-Host ""
}
